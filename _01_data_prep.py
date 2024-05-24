from lxml import etree as et
import requests
from pathlib import Path
import duckdb

Path("data").mkdir(parents=True, exist_ok=True)


def scrap_folder(endpoint):
    Path("data", endpoint).mkdir(parents=True, exist_ok=True)
    url = f"https://kohesio.ec.europa.eu/data/{endpoint}/"  # Replace with your desired URL
    response = requests.get(url)
    print(response)
    xmldata = et.HTML(response.content)

    csv_links = xmldata.xpath("//a[contains(@href, '.csv')]/@href")

    # Print the CSV links
    for link in csv_links:
        print(link)

        if "latest_" in Path(link).name:
            r = requests.get(url + Path(link).name, allow_redirects=True)
            open(Path(Path("data", endpoint), Path(link).name), "wb").write(r.content)


scrap_folder("nuts")
scrap_folder("projects")
scrap_folder("beneficiaries")


def export_to_parquet(endpoint):
    con = duckdb.connect()
    with open(
        f"sql/{endpoint}.sql",
        "r",
    ) as file:
        sql_query = file.read()
    con.execute(sql_query)


export_to_parquet("projects")
export_to_parquet("nuts")
export_to_parquet("beneficiaries")
export_to_parquet("nuts_pop")
export_to_parquet("nuts_gdp")
export_to_parquet("expenditure_per_nuts3")
