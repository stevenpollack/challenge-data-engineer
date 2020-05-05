# using docker's mysql image
For security purposes, you cannot connect to the mysql server from outside the container, so you need to grep the container logs for the generated password, then enter the container and change some security settings.

1. Change your `root` MySQL user password:
```
$docker exec -it mysql57 mysql -uname -p
p: (enter generated password)
mysql>ALTER USER 'root'@'localhost' IDENTIFIED BY 'password'
```
substitute `password` with something secure... You can avoid this step if you initialize your container via
```
$docker run --name mysql57 -p 3306:3306/tcp -e MYSQL_ROOT_PASSWORD=password -d mysql/mysql-server:5.7
```
(I'm booting MySQL v5.7 for compatibility purposes)

2. Change the connection settings so that `root` can be accessed from any IP:
```
mysql>UPDATE mysql.user SET host = '%' where user='root';
```
3. restart the docker image:
```
$docker restart mysql80
```
Provided you mapped your ports like:
```
$docker run -p 3306:3306/tcp --name=mysql80 -d mysql/mysql-server
```
you should now be able to connect via `'root'@localhost:3306`...

# python requirements:
You'll need the `mysql-connector-python` package to run the `python_ddl.py` script:
```
conda install -c anaconda mysql-connector-python
```
or `pip` should fetch it without too many issues.

`Standard` entities are authored by individuals and can be identified by their `standard_doc_id`

technical limitations:

1. there were/are duplicate records in the `declarations.csv` data dump. I could've cleaned them in data pre-processing, but I decided to `INSERT` the data into a `try...except...` block and look for the `IntegrityError` exception to skip the insertion. This is predicated upon the idea that my `declarations` table has defined its primary key via
```
PRIMARY KEY (declaration date, std_doc_id, std_proj, publication_nr)
```
From my data exploration, this is a minimal identifying set of keys, so I was a bit stumped to notice that the dump has duplicates.

docker password:
.ym#eg8Uz-ANPecynosbegOgnAn