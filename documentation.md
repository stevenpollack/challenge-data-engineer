`Standard` entities are authored by individuals and can be identified by their `standard_doc_id`

technical limitations:

1. there were/are duplicate records in the `declarations.csv` data dump. I could've cleaned them in data pre-processing, but I decided to `INSERT` the data into a `try...except...` block and look for the `IntegrityError` exception to skip the insertion. This is predicated upon the idea that my `declarations` table has defined its primary key via
```
PRIMARY KEY (declaration date, std_doc_id, std_proj, publication_nr)
```
From my data exploration, this is a minimal identifying set of keys, so I was a bit stumped to notice that the dump has duplicates.
