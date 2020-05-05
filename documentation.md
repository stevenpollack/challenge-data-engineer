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

# analysis

## most cited patents:
```sql
select cited_patent_nr, count(patent_nr) as num_citations from prior_art
where cited_patent_nr <> ""
GROUP BY cited_patent_nr
order by num_citations desc
```

**Query result 9 rows!**

cited_patent_nr | num_citations
--- | ---
WO2014067166A1 | 4
WO2012093901A2 | 3
WO2012064093A2 | 3
WO2018127074A1 | 3
US8199719B2 | 3
US20180192404A1 | 2
US20160366720A1 | 2
US20130281096A1 | 2
KR2014009289A | 1

## downstream consequences of cited patents:
Say we wanted to investigated the most cited patents in the database, and understand what
their influence would be on future work. I.e., what would the average `technical_relevance` and `market_coverage` of a descendant patents look like. Moreover, how often is prior work
build upon solely by the a single applicant?

# Query result
```sql
SELECT 
    cited_patent_nr,
    COUNT(DISTINCT (publication_nr)) AS num_citations,
    AVG(technical_relevance) AS avg_tr,
    AVG(market_coverage) AS avg_mc,
    COUNT(DISTINCT (applicant)) AS num_unique_applicants,
    AVG(family_size) AS avg_family_size,
    AVG(granted) AS perc_granted,
    AVG(lapsed) AS perc_lapsed
FROM
    patents
        INNER JOIN
    (SELECT 
        cited_patent_nr, patent_nr
    FROM
        prior_art
    WHERE
        cited_patent_nr <> '') AS cited_patents ON (patents.publication_nr = cited_patents.patent_nr)
GROUP BY cited_patent_nr
ORDER BY cited_patent_nr DESC
```

**Query result 9 rows**

cited_patent_nr | num_citations | avg_tr | avg_mc | num_unique_applicants | avg_family_size | perc_granted | perc_lapsed
--- | --- | --- | --- | --- | --- | --- | ---
WO2018127074A1 | 3 | 0.7993568579355875 | 1.2580192188421886 | 2 | 5.6667 | 0.6667 | 0
WO2014067166A1 | 4 | 1.1488415598869324 | 1.1246584430336952 | 3 | 4.75 | 0.75 | 0
WO2012093901A2 | 3 | 0.9965272744496664 | 0.9434707462787628 | 3 | 3.6667 | 0.6667 | 0
WO2012064093A2 | 3 | 0.9965272744496664 | 0.9434707462787628 | 3 | 3.6667 | 0.6667 | 0
US8199719B2 | 3 | 0.9965272744496664 | 0.9434707462787628 | 3 | 3.6667 | 0.6667 | 0
US20180192404A1 | 2 | 0 | 1.0498121529817581 | 2 | 4.5 | 1 | 0
US20160366720A1 | 2 | 0 | 1.0498121529817581 | 2 | 4.5 | 1 | 0
US20130281096A1 | 2 | 0 | 1.0498121529817581 | 2 | 4.5 | 1 | 0
KR2014009289A | 1 | 0 | 1.704514980316162 | 1 | 8 | 1 | 0

It seems as if, for this small sample, none of the descendant patents lapsed, and only 25%
failed to get granted. Moreover, the most cited patent, `WO2014067166A1`, was used by
3 different applicants and had the second highest average TR.