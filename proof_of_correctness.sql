# patents.csv
SELECT 
    pubs.*, cited_work
FROM
    (SELECT 
        patent_nr AS pub,
            GROUP_CONCAT(cited_patent_nr
                SEPARATOR ' | ') AS cited_work
    FROM
        iplytics.prior_art
    GROUP BY pub) AS citations
        INNER JOIN
    (SELECT 
        inventors, patents.*
    FROM
        patents
    INNER JOIN (SELECT 
        publication_nr AS pub,
            GROUP_CONCAT(inventor
                SEPARATOR ' | ') AS inventors
    FROM
        iplytics.patent_inventors
    GROUP BY publication_nr) AS inventors ON (patents.publication_nr = inventors.pub)) AS pubs ON (pubs.publication_nr = citations.pub);

# standards.csv
SELECT authors.authors, standards.*
FROM
    standards
INNER JOIN
    (SELECT std_doc_id, GROUP_CONCAT(author SEPARATOR ' | ') AS authors
     FROM standard_authors
     GROUP BY std_doc_id) AS authors
 ON (standards.std_doc_id = authors.std_doc_id);

# declarations.csv
SELECT * FROM declarations;