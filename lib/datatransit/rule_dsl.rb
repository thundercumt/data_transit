# To change this license header, choose License Headers in Project Properties.
# To change this template file, choose Tools | Templates
# and open the template in the editor.

#chain_filter1 --> chain_filter2 --> chain_filter3

require 'singleton'
require 'progress_bar'

#require File::expand_path('../database', __FILE__)
require File::expand_path('../model/tables_source', __FILE__)
require File::expand_path('../model/tables_target', __FILE__)

module RULE_DSL
  
  class Task
    attr_accessor :tables, :search_cond, :pk, :pre_work, :post_work, :filter
    
    def pk
      @pk ||= []
    end
  end
  
  class TaskSet
    def initialize
      @tasks = []
    end
    
    def push_back task
      @tasks << task
    end
    
    def pop_head
      @tasks.delete_at 0
    end
    
    def first_task
      @tasks[0]
    end
    
    def last_task
      @tasks[@tasks.length - 1]
    end
    
    def length
      @tasks.length
    end
    
    def task_at idx
      @tasks[idx]
    end
    
    def each 
      for i in 0 .. @tasks.length-1
        yield @tasks[i]
      end
    end
  end
  
  def load_rule *rule_file
    rule_file.each{ |file| self.instance_eval File.read(file), file }
  end
  
  def migrate &script
    @taskset ||= TaskSet.new
    task = Task.new
    @taskset.push_back task
    yield 
  end
  
  def choose_table *tables
    task = @taskset.last_task
    task.tables = tables
  end

  def batch_by search_cond
    task = @taskset.last_task
    task.search_cond = search_cond
  end
  
  def register_primary_key *key
    task = @taskset.last_task
    task.pk = key.map(&:downcase)
  end

  def filter_out_with &filter
    task = @taskset.last_task
    task.filter = filter
  end
  
  def pre_work &pre
    task = @taskset.last_task
    task.pre_work = pre
  end
  
  def post_work &post
    task = @taskset.last_task
    task.post_work = post
  end
  
  def get_all_tables
    tables = []
    @taskset.each { |task| tables << task.tables }
    tables.flatten!
  end
end

class DTWorker
  include RULE_DSL
  attr_accessor :batch_size
  
  def initialize rule_file
    @rule_file = rule_file
    @batch_size = 500
  end
  
  def load_work
    load_rule @rule_file
  end
  
  def do_work
    #we copy all or nothing. a mess is not welcome here
    #on failures, transaction will rollback automatically
    DataTransit::Target::TargetBase.transaction do
      @taskset.each do |task|
        do_task task
      end
    end
  end
  
  def do_task task
    pks = task.pk#a context-free-variable in context switches
    tables = task.tables
    
    tables.each do |tbl|
      sourceCls = Class.new(DataTransit::Source::SourceBase) do
        self.table_name = tbl
      end

      #columns = sourceCls.columns.map(&:name).map(&:downcase)
      columns = sourceCls.columns
      
      pk, pk_type = get_pk_column(columns, pks)

      sourceCls.instance_eval( "self.primary_key = \"#{pk}\"") if pk != nil

      targetCls = Class.new(DataTransit::Target::TargetBase) do
        self.table_name = tbl
      end
      targetCls.instance_eval( "self.primary_key = \"#{pk}\"") if pk != nil

      print "\ntable ", tbl, ":\n"
      do_user_ar_proc targetCls, task.pre_work if task.pre_work
      do_batch_copy sourceCls, targetCls, task, pk, pk_type=="integer"
      do_user_ar_proc targetCls, task.post_work if task.post_work
    end
  end
  
  def do_user_ar_proc targetCls, proc
    proc.call targetCls
  end
  
  def do_batch_copy (sourceCls, targetCls, task, pk = nil, in_batch = false)
    count = sourceCls.where(task.search_cond).size.to_f
    return if count <= 0
    
    #clear target table rows in case of violating pk constraint, etc
    targetCls.delete_all(task.search_cond)
    
    next_id = targetCls.maximum(targetCls.primary_key) || 0 #defaults to zero
    next_id += 1
    
    how_many_batch = (count / @batch_size).ceil
    #the progress bar
    bar = ProgressBar.new(count)
    
    if in_batch 
      0.upto (how_many_batch-1) do |i|  
        sourceCls.where(task.search_cond).find_each(
          start: i * @batch_size, batch_size: @batch_size) do |source_row|
          
          #update progress
          bar.increment!
          
          if task.filter
            next if do_filter_out task.filter, source_row
          end
          target_row = targetCls.new source_row.attributes

          #activerecord would ignore pk field, and the above initialization will result nill primary key.
          #here the original pk is used in the target_row, it is what we need exactly.
          if pk 
            if source_row.has_attribute?(pk)
              target_row.send( "#{pk}=", source_row.send("#{pk}") )
            else
              target_row.send( "#{pk}=",  next_id)
              next_id += 1
            end
          end

          target_row.save
        end
      end
    else
      sourceCls.where(task.search_cond).each do |source_row|
        #update progress
        bar.increment!
        
        if task.filter
          next if do_filter_out task.filter, source_row
        end
        target_row = targetCls.new source_row.attributes

        #activerecord would ignore pk field, and the above initialization will result nill primary key.
        #here the original pk is used in the target_row, it is what we need exactly.
        if pk 
          if source_row.has_attribute?(pk)
            target_row.send( "#{pk}=", source_row.send("#{pk}") )
          else
            target_row.send( "#{pk}=",  next_id)
            next_id += 1
          end
        end

        target_row.save
      end
    end
    
    
  end
  
  def do_filter_out filter, row
    if filter.call row
      return true
    end
    false
  end
  
  private
  def get_pk_column(columns, given_pk)
    column_names = columns.map(&:name).map(&:downcase)
    pk = column_names & given_pk
    if pk && pk.length > 0
      pk = pk[0]
      pk_column = columns[column_names.index(pk)]
      if(pk_column.type == :integer) #active record mandates a int primary key
        return pk_column.name, pk_column.type
      else
        raise ActiveRecord::ActiveRecordError, 
          "ActiveRecord Mandates an Integer Primary Key, for Column #{pk_column.name}"
      end
    end
    
    # check conflicts against default id prerequsite
    id_idx = column_names.index('id')
    if id_idx != nil
      if columns[id_idx].type != :integer
        raise ActiveRecord::ActiveRecordError, "ActiveRecord Mandates an Integer Primary Key, Default Name 'ID'"
      else
        return columns[id_idx].name, columns[id_idx].type
      end
    else
        return 'id', :integer #default column 'id' 
    end
  
  end
  
end