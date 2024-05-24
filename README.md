# Kohesio
Playing with the [Kohesio](https://kohesio.ec.europa.eu/en/) data with [duckdb](https://duckdb.org/) &amp; [echarts4r](https://echarts4r.john-coene.com/)


### Overview

My favorite way to go when explorating data : process the data with **duckdb**, an amazing Swiss knife (think pandas in SQL) and explore them with **echarts**, an open-sourced visualization library provided by Baidu. 

Here we use a python script to scrap the Kohesio data, enrich them with the Eurostats [GDP](https://ec.europa.eu/eurostat/fr/web/products-datasets/product?code=nama_10r_3gdp) and [Population](
https://ec.europa.eu/eurostat/databrowser/view/DEMO_R_D3DENS/default/table?lang=en) data points per NUTS3 Level, and finally plot them.




### 1 - Scrap data and store the data locally

just run the following python script :
```bash
pip install -r requirements.txt
python _01_data_prep.py
```

### 2 - Run the R Notebook

open the *EDA.Rmd* and knit it.


Output can be found in **EDA.html** : [just download the file and open it with a browser](https://github.com/clementlefevre/Kohesio/blob/main/EDA.html)


![Demo](https://github.com/clementlefevre/Kohesio/blob/main/pic_1.png?raw=true)



