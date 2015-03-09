<div><b>data_transit</b></div><div>data_transit is a ruby gem/app used to migrate between different relational&nbsp;<span style="line-height: 1.7;">databases, supporting customized migration procedure.</span></div><div><br></div><div><b>1 Introduction</b></div><div>data_transit relies on activerecord to generate database Models on the fly.&nbsp;<span style="line-height: 1.7;">Tt is executed within a database transaction, and should any error occur during&nbsp;</span><span style="line-height: 1.7;">data transit, it will cause the transaction to rollback. So don't worry about&nbsp;</span><span style="line-height: 1.7;">introducing dirty data into your target database.</span></div><div><br></div><div><b>2 Install</b></div><div>data_transit can be installed using gem</div><div>&nbsp; &nbsp; gem install data_transit</div><div>or&nbsp;</div><div>&nbsp; &nbsp; download data_transit.gem</div><div>&nbsp; &nbsp; gem install --local /where/you/put/data_transit.gem</div><div><br></div><div>In your command line, input data_transit, You can proceed to "how to use" if you&nbsp;<span style="line-height: 1.7;">can see message prompt as below.&nbsp;</span></div><div><span style="line-height: 1.7;">data_transit&nbsp;</span></div><div><span style="line-height: 1.7;">usage: data_transit command args. 4 commands are listed below...</span></div><div><br></div><div><br></div><div><b>3 How to use</b></div><div><br></div><div><b>3.1 Config DataBase Connection</b></div><div>&nbsp; &nbsp; data_transit setup_db_conn /your/yaml/database/config/file</div><div><br></div><div>Your db config file should be compatible with the activerecord adapter you are&nbsp;<span style="line-height: 1.7;">using and configured properly. As the name suggests, source designates which&nbsp;</span><span style="line-height: 1.7;">database you plan to copy data from, while target means the copy destination.&nbsp;</span><span style="line-height: 1.7;">Note the key 'source' and 'target' should be kept unchanged!&nbsp;</span></div><div><span style="line-height: 1.7;">For example, here is sample file for oracle dbms.</span></div><div><br></div><div>database.yml</div><div>source:#don't change this line</div><div>&nbsp; adapter: oracle_enhanced</div><div>&nbsp; database: dbserver</div><div>&nbsp; username: xxx</div><div>&nbsp; password: secret</div><div><br></div><div>target:#don't change this line</div><div>&nbsp; adapter: oracle_enhanced</div><div>&nbsp; database: orcl</div><div>&nbsp; username: copy1</div><div>&nbsp; password: cipher</div><div><br></div><div><br></div><div><b>3.2 Create Database Schema(optional)</b></div><div>If you can have your target database schema created, move to 3.3 "copy data",&nbsp;<span style="line-height: 1.7;">otherwise use your database specific tools to generate an identical schema in&nbsp;</span><span style="line-height: 1.7;">your target database. Or if you don't have a handy tool to generate the schema,&nbsp;</span><span style="line-height: 1.7;">for instance when you need to migrate between different database systems, you&nbsp;</span><span style="line-height: 1.7;">can use data_transit to dump a schema description file based on your source&nbsp;</span><span style="line-height: 1.7;">database schema, and then use this file to create your target schema.</span></div><div><br></div><div>Note this gem is built on activerecord, so it should work well for the database&nbsp;<span style="line-height: 1.7;">schema compatible with rails conventions. Example, a single-column primary key &nbsp;</span><span style="line-height: 1.7;">rather than a compound primary key (primary key with more than one columns),&nbsp;</span><span style="line-height: 1.7;">primary key of integer type instead of other types like guid, timestamp etc.</span></div><div><br></div><div>In data_transit, I coded against the situation where non-integer is used,&nbsp;<span style="line-height: 1.7;">therefore resulting a minor problem that the batch-query feature provided by&nbsp;</span></div><div>activerecord can not be used because of its dependency on integer primary key.&nbsp;<span style="line-height: 1.7;">In this special case, careless selection of copy range might overburden network,&nbsp;</span><span style="line-height: 1.7;">database server because all data in the specified range are transmitted from the&nbsp;</span><span style="line-height: 1.7;">source database and then inserted into the target database.</span></div><div><br></div><div><br></div><div><b>3.2.1 Dump Source Database Schema</b></div><div>&nbsp; &nbsp; data_transit dump_schema [schema_file] [rule_file]</div><div>[schema_file] will be used to contain dumped schema, [rule_file] describes how&nbsp;<span style="line-height: 1.7;">your want data_transit to copy your data.</span></div><div><br></div><div>Note if your source schema is somewhat a legacy, you might need some manual work&nbsp;<span style="line-height: 1.7;">to adjust the generated schema_file to better meet your needs.&nbsp;</span></div><div><br></div><div>For example, in my test, the source schema uses obj_id as id, and uses guid as&nbsp;<span style="line-height: 1.7;">primary key type, so I need to impede activerecord auto-generating "id" column&nbsp;</span><span style="line-height: 1.7;">by removing primary_key =&gt; "obj_id" and adding :id=&gt;false, and then appending&nbsp;</span><span style="line-height: 1.7;">primary key constraint in the end of each table definition. See below.</span></div><div><br></div><div>here is an example dumped schema file</div><div><br></div><div>ActiveRecord::Schema.define(:version =&gt; 0) do</div><div>&nbsp; create_table "table_one", primary_key =&gt; "obj_id", :force =&gt; true do |t|</div><div>&nbsp; &nbsp; #other fields</div><div>&nbsp; end</div><div>&nbsp; #other tables</div><div>end</div><div><br></div><div>and I manually changed the schema definition to</div><div><br></div><div>ActiveRecord::Schema.define(:version =&gt; 0) do</div><div>&nbsp; create_table "table_one", :id =&gt; false, :force =&gt; true do |t|</div><div>&nbsp; &nbsp; t.string "obj_id", &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; :limit =&gt; 42 &nbsp;</div><div>&nbsp; &nbsp; #other fields</div><div>&nbsp; end</div><div>&nbsp; execute "alter table table_one add primary key(obj_id)"</div><div>end</div><div><br></div><div><b>3.2.2 Create Target Database Schema</b></div><div>&nbsp; &nbsp; data_transit create_table [schema_file]</div><div>If everything goes well, you will see a bunch of ddl execution history.</div><div><br></div><div><br></div><div><b>3.3 Copy Data</b></div><div>&nbsp; &nbsp; data_transit copy_data [rule_file]</div><div>[rule_file] contains your copy logic. For security reasons, I changed table names</div><div>and it looks as follows.</div><div><br></div><div>#start of rule</div><div>start_date = "2015-01-01 00:00:00"</div><div>end_date = "2015-02-01 00:00:00"</div><div><br></div><div>migrate do</div><div>&nbsp; choose_table "APP.TABLE1","APP.TABLE2","APP.TABLE3","APP.TABLE4","APP.TABLE5","APP.TABLE6"</div><div>&nbsp; batch_by "ACQUISITION_TIME BETWEEN TO_DATE('#{start_date}','yyyy-mm-dd hh24:mi:ss') AND TO_DATE('#{end_date}', 'yyyy-mm-dd hh24:mi:ss')"</div><div>&nbsp; register_primary_key 'OBJ_ID'</div><div>end</div><div><br></div><div>migrate do</div><div>&nbsp; choose_table "APP.TABLE7","APP.TABLE8","APP.TABLE9","APP.TABLE10","APP.TABLE11","APP.TABLE12"</div><div>&nbsp; batch_by "ACKTIME BETWEEN TO_DATE('#{start_date}','yyyy-mm-dd hh24:mi:ss') AND TO_DATE('#{end_date}', 'yyyy-mm-dd hh24:mi:ss')"</div><div>&nbsp; register_primary_key 'OBJ_ID'</div><div>end</div><div><br></div><div>migrate do</div><div>&nbsp; choose_table "APP.TABLE13","APP.TABLE14","APP.TABLE15","APP.TABLE16","APP.TABLE17","APP.TABLE18"</div><div>&nbsp; batch_by "1&gt;0" #query all data because these tables don't have a reasonable range</div><div>&nbsp; register_primary_key 'OBJ_ID'</div><div>&nbsp; pre_work do |targetCls| targetCls.delete_all("1&gt;0") &nbsp;end #delete all in target</div><div>&nbsp; #post_work do |targetCls| &nbsp;end</div><div>end</div><div><br></div><div>#end of rule</div><div><br></div><div><br></div><div>Each migrate block contains a data_transit task.&nbsp;</div><div><br></div><div>"choose_table" describes which tables are included in this task. These tables&nbsp;</div><div>share some nature in common, and can be processed with the same rule.&nbsp;</div><div><br></div><div>"batch_by" is the query condition</div><div><br></div><div>"register_primary_key" describes the primary key of the tables.</div><div><br></div><div>"pre_work" is a block executed before each table is processed.</div><div><br></div><div>"post_work" is a block executed after each table is processed.</div>