---
layout: page
title: Wikidata Queries from a Jupyter Notebook with Elixi
permalink: jupyter/
---

## Setting up the environment

IElixir uses the concept of virtual environments for managing packages. It uses [`Boyle`](https://github.com/pprzetacznik/IElixir#package-management-with-boyle) as its package manager.

Let's first create a `sparql_env` environment for our SPARQL dependencies using `Boyle.mk/1`. (Note also that there is a previously created an `rdf_env` environment set up for separately exploring [RDF.ex](https://hex.pm/packages/rdf) which we can just ignore.)


```elixir
> Boyle.mk("sparql_env")

All dependencies up to date
{:ok, ["sparql_env", "wikidata"]}
```

Next step is to activate the environment which will take care of compiling.

```elixir
> Boyle.activate("sparql_env")

All dependencies up to date
:ok
```

Next we install the dependencies:

```elixir
> Boyle.install({:sparql_client, "~> 0.2.1"})

:ok
```

## Running ae example SPARQL.Client query

Let's choose a SPARQL endpoint, obviously, we take Wikidata:

```elixir
> service = "https://query.wikidata.org/bigdata/namespace/wdq/sparql"

"https://query.wikidata.org/bigdata/namespace/wdq/sparql"
```

We take a query from the examples section of the query web service: The search for the biggest cities ruled by a female mayor:

```elixir
> query = """
    SELECT DISTINCT ?city ?cityLabel ?mayor ?mayorLabel ?population WHERE
    {
        BIND(wd:Q6581072 AS ?sex)
        BIND(wd:Q515 AS ?c)
        ?city wdt:P31/wdt:P279* ?c .
        ?city p:P6 ?statement .
        ?statement ps:P6 ?mayor .
        ?mayor wdt:P21 ?sex .
        FILTER NOT EXISTS { ?statement pq:P582 ?x }
        ?city wdt:P1082 ?population .
        SERVICE wikibase:label {
            bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en" .
        }
    }
    ORDER BY DESC(?population)
    LIMIT 5
  """

"SELECT DISTINCT ?city ?cityLabel ?mayor ?mayorLabel ?population WHERE\n{\n    BIND(wd:Q6581072 AS ?sex)\n    BIND(wd:Q515 AS ?c)\n    ?city wdt:P31/wdt:P279* ?c .\n    ?city p:P6 ?statement .\n    ?statement ps:P6 ?mayor .\n    ?mayor wdt:P21 ?sex .\n    FILTER NOT EXISTS { ?statement pq:P582 ?x }\n    ?city wdt:P1082 ?population .\n    SERVICE wikibase:label {\n        bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\" .\n    }\n}\nORDER BY DESC(?population)\nLIMIT 5\n"
```

Let's run the query and capture the results:

```elixir
> {:ok, %SPARQL.Query.Result{results: results}} = 
    SPARQL.Client.query(query, service, request_method: :get, 
                                        protocol_version: "1.1")

{:ok, %SPARQL.Query.Result{results: [%{"city" => ~I<http://www.wikidata.org/entity/Q1490>, "cityLabel" => ~L"Tokyo"en, "mayor" => ~I<http://www.wikidata.org/entity/Q261703>, "mayorLabel" => ~L"Yuriko Koike"en, "population" => ~L"13784212"}, %{"city" => ~I<http://www.wikidata.org/entity/Q8646>, "cityLabel" => ~L"Hong Kong"en, "mayor" => ~I<http://www.wikidata.org/entity/Q19217>, "mayorLabel" => ~L"Carrie Lam"en, "population" => ~L"7336585"}, %{"city" => ~I<http://www.wikidata.org/entity/Q1530>, "cityLabel" => ~L"Baghdad"en, "mayor" => ~I<http://www.wikidata.org/entity/Q19367467>, "mayorLabel" => ~L"Zekra Alwach"en, "population" => ~L"6960000"}, %{"city" => ~I<http://www.wikidata.org/entity/Q11462>, "cityLabel" => ~L"Surabaya"en, "mayor" => ~I<http://www.wikidata.org/entity/Q12522317>, "mayorLabel" => ~L"Tri Rismaharini"en, "population" => ~L"4975000"}, %{"city" => ~I<http://www.wikidata.org/entity/Q38283>, "cityLabel" => ~L"Yokohama"en, "mayor" => ~I<http://www.wikidata.org/entity/Q529363>, "mayorLabel" => ~L"Fumiko Hayashi"en, "population" => ~L"3731706"}], variables: ["city", "cityLabel", "mayor", "mayorLabel", "population"]}}
```

Pretty printing that helps us humans capture the structure of the result more easily...

```elixir
> IO.inspect(results); nil

[
  %{
  "city" => ~I<http://www.wikidata.org/entity/Q1490>,
  "cityLabel" => ~L"Tokyo"en,
  "mayor" => ~I<http://www.wikidata.org/entity/Q261703>,
  "mayorLabel" => ~L"Yuriko Koike"en,
  "population" => ~L"13784212"
  },
  %{
  "city" => ~I<http://www.wikidata.org/entity/Q8646>,
  "cityLabel" => ~L"Hong Kong"en,
  "mayor" => ~I<http://www.wikidata.org/entity/Q19217>,
  "mayorLabel" => ~L"Carrie Lam"en,
  "population" => ~L"7336585"
  },
  %{
  "city" => ~I<http://www.wikidata.org/entity/Q1530>,
  "cityLabel" => ~L"Baghdad"en,
  "mayor" => ~I<http://www.wikidata.org/entity/Q19367467>,
  "mayorLabel" => ~L"Zekra Alwach"en,
  "population" => ~L"6960000"
  },
  %{
  "city" => ~I<http://www.wikidata.org/entity/Q11462>,
  "cityLabel" => ~L"Surabaya"en,
  "mayor" => ~I<http://www.wikidata.org/entity/Q12522317>,
  "mayorLabel" => ~L"Tri Rismaharini"en,
  "population" => ~L"4975000"
  },
  %{
  "city" => ~I<http://www.wikidata.org/entity/Q38283>,
  "cityLabel" => ~L"Yokohama"en,
  "mayor" => ~I<http://www.wikidata.org/entity/Q529363>,
  "mayorLabel" => ~L"Fumiko Hayashi"en,
  "population" => ~L"3731706"
  }
]
nil
```

Let's dig deeper into the first label:

```elixir
> citylabel = List.first(results)["cityLabel"]

~L"Tokyo"en
```

That is an RDF literal, it has a language and a value attribute:

```elixir
> citylabel.language

"en"
```

```elixir
> citylabel.value

"Tokyo"
```

And that's all I've got for now!
