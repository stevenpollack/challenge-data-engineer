import mysql.connector as mysql
from mysql.connector import errorcode
import datetime, re, csv

# delete db before closing connection?
cleanup = False 
# delete and remake tables?
clean_start = True

db = mysql.connect(
  host = "localhost",
  user = "root",
  passwd = "password"
)

cursor = db.cursor()
# ignore FOREIGN KEY checks will building and populating tables
cursor.execute("SET foreign_key_checks = 0;")
# turn on autocommit to make insertions stick
cursor.execute("SET autocommit = 1;")

# connect to DB -- create if it doesn't exist
DB_NAME = "IPlytics"
try:
  cursor.execute("USE {}".format(DB_NAME))
except mysql.ProgrammingError as err:
  if err.errno == 1049:
    print("{} database doesn't exist... Making it now.".format(DB_NAME))
    cursor.execute("CREATE DATABASE {};".format(DB_NAME))
    cursor.execute("USE {};".format(DB_NAME))
    warnings = cursor.fetchwarnings()
    if warnings:
      print(warnings)
    else:
      print("{} successfully created and set.".format(DB_NAME))

# create our tables:
TABLES = {}
TABLES['patents'] = ("""CREATE TABLE patents (
    title VARCHAR(400) NOT NULL,
    publication_nr VARCHAR(40) NOT NULL,
    family_id VARCHAR(40),
    applicant VARCHAR(40) NOT NULL,
    patent_office VARCHAR(20) NOT NULL,
    publication_date DATE NOT NULL,
    kind_type VARCHAR(20),
    granted BOOLEAN,
    lapsed BOOLEAN,
    family_size INT,
    market_coverage FLOAT,
    technical_relevance FLOAT,
    PRIMARY KEY (publication_nr),
    INDEX (applicant))
  ENGINE=INNODB;""")

TABLES['patent_inventors'] = ("""CREATE TABLE patent_inventors (
    publication_nr VARCHAR(40) NOT NULL,
    inventor VARCHAR(100) NOT NULL,
    FOREIGN KEY (publication_nr)
        REFERENCES patents (publication_nr)
        ON DELETE CASCADE ON UPDATE CASCADE)
  ENGINE=INNODB;""")

TABLES['prior_art'] = ("""CREATE TABLE prior_art (
  patent_nr VARCHAR(40) NOT NULL,
  cited_patent_nr VARCHAR(40),
  INDEX (patent_nr),
  FOREIGN KEY (cited_patent_nr)
    REFERENCES patents (publication_nr)
    ON DELETE CASCADE ON UPDATE CASCADE)
  ENGINE=INNODB;""")

TABLES['standards'] = """CREATE TABLE standards (
    title VARCHAR(1000) NOT NULL,
    std_doc_id VARCHAR(100) NOT NULL,
    tech_gen VARCHAR(100),
    publication_date DATE NOT NULL,
    sso VARCHAR(100) NOT NULL,
    std_proj VARCHAR(100) NOT NULL,
    version_hist VARCHAR(40) NOT NULL,
    original_doc VARCHAR(256) NOT NULL,
    PRIMARY KEY (std_doc_id),
    INDEX (std_proj)) ENGINE=INNODB;"""

TABLES['standard_authors'] = """CREATE TABLE standard_authors (
    std_doc_id VARCHAR(100) NOT NULL,
    author VARCHAR(100) NOT NULL,
    FOREIGN KEY (std_doc_id)
        REFERENCES standards (std_doc_id)
        ON UPDATE CASCADE ON DELETE CASCADE)
  ENGINE=INNODB;"""

TABLES['declarations'] = """CREATE TABLE declarations (
    declaring_company VARCHAR(100) NOT NULL,
    declaration_date DATE NOT NULL,
    std_proj VARCHAR(100) NOT NULL,
    std_doc_id VARCHAR(100) NOT NULL,
    tech_gen VARCHAR(100) NOT NULL,
    releases VARCHAR(1000) NOT NULL,
    publication_nr VARCHAR(40) NOT NULL,
    application_nr VARCHAR(40) NOT NULL,
    PRIMARY KEY (declaration_date, std_doc_id, std_proj, publication_nr),
    CONSTRAINT FK_STD_DOC_ID FOREIGN KEY (std_doc_id)
        REFERENCES standards (std_doc_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_STD_PROJ FOREIGN KEY (std_proj)
        REFERENCES standards (std_proj)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_APPLICANT FOREIGN KEY (declaring_company)
        REFERENCES patents (applicant)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT FK_PUB_NR FOREIGN KEY (publication_nr)
        REFERENCES patents (publication_nr)
        ON UPDATE CASCADE ON DELETE CASCADE)
  ENGINE=INNODB;"""

for table_name in TABLES:
    table_description = TABLES[table_name]
    try:
        print("Creating table {}: ".format(table_name), end='')
        cursor.execute(table_description)
    except mysql.Error as err:
        if err.errno == errorcode.ER_TABLE_EXISTS_ERROR:
            print("{} already exists!...".format(table_name))
            if clean_start:
              print("Dropping and remaking...")
              cursor.execute("DROP TABLE {};".format(table_name))
              cursor.execute(table_description)
        else:
            print(err.msg)
    else:
        print("OK")


def deaggregateField(row, field_name, key_name, sep="|"):
  values = [value.strip() for value in row[field_name].split(sep)]
  return [(row[key_name], values) for values in values]

def formatPatentData(row):
  row['title'] = "{:.400}".format(row['title'])
  pub_date = row['publication_date']
  row['publication_date'] = datetime.date.fromisoformat(pub_date)
  # if legal status starts with t it's True
  row['lapsed'] = row['lapsed'].startswith('t')
  row['granted'] = row['granted'].startswith('t')

  # deaggregate citations and authors
  row['inventor'] = deaggregateField(row, 'inventor', 'publication_nr')
  row['patent_citation'] = \
    deaggregateField(row, 'patent_citation', 'publication_nr')
  
  return row

def insertDeclarationRowData(cursor, row):
  try:
    cursor.execute("""
    INSERT INTO declarations VALUE (
      %(declaring_company)s, %(declaration_date)s, %(standard_project)s,
      %(standard_document_id)s, %(technology_generation)s, %(releases)s,
      %(publication_nr)s, %(application_nr)s)
    """, row)
  except mysql.IntegrityError as err:
    print("Integrity Error! Not adding data to `declarations`...")
    print("Error message: {}".format(err))

  return row

def insertPatentRowData(cursor, row):
  
  inventors = row.pop('inventor')
  citations = row.pop('patent_citation')

  cursor.execute("""
  INSERT INTO patents VALUE (
    %(title)s, %(publication_nr)s, %(inpadoc_family_id)s,
     %(applicant)s, %(patent_office)s, %(publication_date)s,
     %(kind_type)s, %(granted)s, %(lapsed)s, %(family_size)s,
     %(market_coverage_mc)s, %(technical_relevance_tr)s
  );
  """, row)

  cursor.executemany("""
  INSERT INTO prior_art (patent_nr, cited_patent_nr) 
    VALUES (%s, %s)  
  """, citations)

  cursor.executemany("""
  INSERT INTO patent_inventors (publication_nr, inventor)
    VALUES (%s, UPPER(%s))
  """, inventors)

  row['inventors'] = inventors
  row['citations'] = citations
  return row

def processPatentData(cursor, row):
  data = formatPatentData(row)
  data = insertPatentRowData(cursor, data)
  return data

def processDeclarationsData(cursor, row):
  dec_date = row['declaration_date']
  row['declaration_date'] = datetime.date.fromisoformat(dec_date)
  row = insertDeclarationRowData(cursor, row)
  return row

def processStandardsData(cursor, row):
  # split up authors
  authors = deaggregateField(row, 'author', 'standard_document_id')
  row.pop('author')

  cursor.executemany("""
  INSERT INTO standard_authors VALUE (%s, UPPER(%s))""", authors)
    
  pub_date = datetime.date.fromisoformat(row['publication_date'])
  row['publication_date'] = pub_date
  cursor.execute("""
  INSERT INTO standards VALUE (
    %(title)s, %(standard_document_id)s, %(technology_generation)s,
    %(publication_date)s, %(standard_setting_organization)s,
    %(standard_project)s, %(version_history)s, %(original_document)s
  )
  """, row)

  return row

dataProcessors = {
  'patents': processPatentData,
  'declarations': processDeclarationsData,
  'standards': processStandardsData
}

def ingestDump (filepath, processors=dataProcessors):

  # extract file name without .csv and use that to find proper data processor
  dataType = re.findall(r'(\w*)\.csv$', filepath)[0]
  dataProcessor = processors[dataType]

  print("Processing {}...".format(filepath))

  with open(filepath, encoding='utf-8', newline='') as csvfile:
    reader = csv.DictReader(csvfile, delimiter=",", quotechar='"')

    # remove \s, ., and ()'s from field_names
    reader.fieldnames = [ \
      re.sub(r'[.()]', '', name.replace(' ', '_')).lower() for name in reader.fieldnames]

    rows_processed = 0
    for row in reader:
      data = dataProcessor(cursor, row)
      rows_processed += 1

    csvfile.close()
  print("Done with {}... {} rows processed.".format(filepath, rows_processed))
  return True

dumps = ['./dumps/patents.csv',
         './dumps/standards.csv',
         './dumps/declarations.csv']

for filepath in dumps:
  ingestDump(filepath)

print("Re-enabling foreign key checks in DB for data integrity...")
cursor.execute("SET foreign_key_checks = 1;")

if cleanup:
  print("Cleaning up database...")
  cursor.execute("DROP DATABASE IF EXISTS {};".format(DB_NAME))

print("Closing connection...")
cursor.close()
db.close()
