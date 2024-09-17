Class dc.inGenGBL.Core Extends %RegisteredObject
{

ClassMethod Process(input As %String = "") As %String [ Language = python ]
{
    import os
    from dotenv import load_dotenv

    import iris
    import json

    # Import langchain
    from operator import itemgetter
    from typing import Literal
    from typing_extensions import TypedDict

    from langchain_core.output_parsers import StrOutputParser
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.runnables import RunnableLambda, RunnablePassthrough, RunnableParallel
    from langchain_openai import ChatOpenAI

    load_dotenv()

    def get_global_size(global_name):
        """Call this to get the size of a global"""
        return iris.cls("dc.inGenGBL.Utils").GetGlobalSize(global_name)

    llm = ChatOpenAI(model=os.getenv('LLM_MODEL'), temperature=0, api_key=os.getenv('OPENAI_API_KEY'))

    # Define specialized prompt templates
    mapping_template = iris.cls("dc.inGenGBL.Core").GetMappingTemplate()
    searching_template = iris.cls("dc.inGenGBL.Core").GetSearchingTemplate()

    prompt_1 = ChatPromptTemplate.from_messages(
        [
            ("system", mapping_template),
            ("human", "{input}"),
        ]
    )
    prompt_2 = ChatPromptTemplate.from_messages(
        [
            ("system", searching_template),
            ("human", "{input}"),
        ]
    )

    prompt_3 = ChatPromptTemplate.from_messages(
        [
            ("system", """ You are an InterSystems Multi-Model specialist and \
            an expert in global size analysis.Your task is to analyze the size \
            of a given global and provide detailed information about it. \ 
            Use the get_global_size function to obtain the necessary data.
            """),
            ("human", "{input}"),
        ]
    )

    chain_1 = prompt_1 | llm | StrOutputParser()
    chain_2 = prompt_2 | llm | StrOutputParser()

    chain_3 = RunnableParallel(
        {
            "system": prompt_3 | llm | StrOutputParser(),
            "global_size": lambda x: get_global_size(x["input"])
        }
    )

    MULTI_PROMPT_ROUTER_TEMPLATE = """Given a raw text input to a \
    language model select the model prompt best suited for the input. \
    You will be given the names of the available prompts and a \
    description of what the prompt is best suited for. \
    You may also revise the original input if you think that revising\
    it will ultimately lead to a better response from the language model.
    """

    route_prompt = ChatPromptTemplate.from_messages(
        [
            ("system", MULTI_PROMPT_ROUTER_TEMPLATE ),
            ("human", "{input}"),
        ]
    )

    class RouteQuery(TypedDict):
        """Route query to destination."""
        destination: Literal["mapping globals", "search", "global size"]

    route_chain = (
        route_prompt
        | llm.with_structured_output(RouteQuery)
        | itemgetter("destination")
    )

    chain = {
        "destination": route_chain, 
        "input": lambda x: x["input"],  # pass through input query
    } | RunnableParallel(
        {
            "mapping_globals": lambda x: chain_1 if x["destination"] == "mapping globals" else None,
            "search": lambda x: chain_2 if x["destination"] == "search" else None,
            "global_size": lambda x: chain_3 if x["destination"] == "global size" else None
        }
    ) | RunnableLambda(lambda x: next(item for item in x.values() if item is not None))

    try:
        result = chain.invoke({"input": input})
    except Exception as err:
        result = {"error": str(err)}

    return json.dumps(result)
}

ClassMethod GetMappingTemplate() As %String [ Language = python ]
{
    return """You are an InterSystems Multi-Model expert and a global mapping specialist.\
I will provide you with a global name, the main subscript, and the delimiter used. \
Your task is to analyze the structure and identify the number of pieces in each node, \
as well as the data type of each piece.

You must create a Python ClassMethod as follows:

### Output:
You should produce a JSON object that describes the data structure and its types, which can be later converted into XML. This JSON should include:
- **Subscripts**: Identified from the provided subscript and properly inserted into the output.
- **Data fields**: The number of pieces in each node and their corresponding data types, using `%String`, `%Integer`, `%Date`, `%DateTime`, and `%Numeric`.

### Example Global:
```plaintext
^mapping("Less Simple",1,1)="Bannon,Brendan^Father"
^mapping("Less Simple",1,1,"Activity")="Rock Climbing"
^mapping("Less Simple",1,2)="Bannon,Sharon^Mother"
^mapping("Less Simple",1,2,"Activity")="Yoga"
```

### Sample Python Code:
```python
ClassMethod MappingGlobal() As %String [ Language = python ]
{{
    import iris
    import json

    def dataType_identify(value):
        if isinstance(value, (int, float)) or (isinstance(value, str) and '.' in value and value.replace('.', '').isdigit()):
            return "%Numeric"
        elif isinstance(value, str):
            if value.isdigit() and len(value) == 5:
                return "%Date"
            elif ',' in value and all(part.isdigit() for part in value.split(',')):
                return "%DateTime"
            elif value.isdigit():
                return "%Integer"
            else:
                return "%String"
        return "%String"

    # Validate subscript input
    if not isinstance(subscript, str) or not subscript:
        return {{"error": "Invalid subscript provided"}}

    # Initialize global and variables
    try:
        mapping = iris.gref(name)
    except Exception as e:
        return {{"error": str(e)}}

    delimiter = separator if separator else "^"
    json_obj = {{
        "Storage": {{
            "Type": "%CacheSQLStorage",
            "StreamLocation": "^Mapping.Example2S",
            "SQLMap": {{
                "Type": "data",
                "Global": name,
                "Subscript": [],
                "Data": [],
                "_name": "Map1"
            }},
            "_name": "NewStorage1"
        }}
    }}

    # Parse subscript structure
    subscripts = subscript.split(",")
    for idx, subs in enumerate(subscripts):
        json_obj["Storage"]["SQLMap"]["Subscript"].append({{
            "Expression": subs,
            "_name": str(idx + 1)
        }})

    # Sample records to determine data types
    sample_count = 100
    key = ""
    content = []

    for _ in range(sample_count):
        row = {{}}
        key = mapping.order(subscripts + [key])
        if key is None:
            break
        row["key"] = dataType_identify(key)

        reg = mapping.get(subscripts + [key])
        data = []
        columns = reg.split(delimiter)
        for column in columns:
            data.append(dataType_identify(column))

        k = ''
        if mapping.data(subscripts + [key]) > 0:
            for (k, value) in mapping.orderiter(subscripts + [key, k]):
                data.append(k[-1])
        
        row["data"] = data
        content.append(row)

    # Analyze data types
    keys_type = {{}}
    data_type = []

    for item in content:
        key_type = item['key']
        keys_type[key_type] = keys_type.get(key_type, 0) + 1

        for index, dataItem in enumerate(item["data"]):
            if len(data_type) <= index:
                data_type.append({{}})
            dataItem_type = dataItem
            if dataItem_type not in data_type[index]:
                data_type[index][dataItem_type] = 0
            data_type[index][dataItem_type] += 1

    # Assign the most frequent data type for subscripts and fields
    json_obj['Storage']['SQLMap']['Subscript'][2]['_type'] = max(keys_type, key=keys_type.get)
    for index in range(len(data_type)):
        dtype = max(data_type[index], key=data_type[index].get)
        json_obj['Storage']['SQLMap']['Data'].append({{
            "Delimiter": delimiter,
            "Piece": index + 1,
            "_name": "col" + str(index),
            "_type": dtype
        }})

    return json.dumps(json_obj)
}}
```

    
    """
}

ClassMethod GetSearchingTemplate() As %String [ Language = python ]
{
    return """You are an InterSystems Multi-Model expert and a InterSystems Iris global searching specialist.\
I will provide you with a global name, the main subscript if needed, and the delimiter used. \
Your task is to analyze the structure and identify the number of pieces in each node, \
as well as the data type of each piece.

You must create a Python ClassMethod as follows:

### Input:
- **Global name**: For example, `"^mapping"`.
- **Subscript**: Provided by the user, such as `"Less Simple,1"`.
- **Delimiter**: Provided by the user (e.g., `","`), defaulting to a caret (`"^"`).

### Output:
You should produce a JSON object that describes the data structure and its types, which can be later converted into XML. This JSON should include:
- **Key**: Identified from the provided subscript and properly inserted into the subscript that contain the output.
- **Content**: The founded register.

### Example Global:
```plaintext
^mlb = "Major League Baseball"
^mlb("AL") = "American League"
^mlb("AL","Central") = "AL Central"
^mlb("AL","East") = "AL East"
^mlb("AL","East",1) = "Baltimore"
^mlb("AL","East",2) = "Boston"
^mlb("AL","East",3) = "NY Yankees"
^mlb("AL","East",4) = "Tampa Bay"
^mlb("AL","East",5) = "Toronto"
^mlb("AL","West") = "AL West"
^mlb("AL","West",1) = "Houston"
^mlb("AL","West",2) = "LA Angels"
^mlb("AL","West",3) = "Oakland"
^mlb("AL","West",4) = "Seattle"
^mlb("AL","West",5) = "Texas"
^mlb("NL") = "National League"
```

### Sample Python Code:
Search for "Houston" in ^mlb global
```python
ClassMethod SearchingGlobal() As %Status [ Language = python ]
{{
    import iris
    import json
    import pandas as pd

    found = []
    m = iris.gref('^mlb')
    key = ''
    search = 'Houston'
    while True:
        key = m.order([key])
        if key == None:
            break
        s = m.get([key])
        if search in s:
            found.append({{"key":[key], "content": s}})
        if (m.data([key]) > 0):
            lvl1 = True
            subs1 = ''
            while (lvl1):
                subs1 = m.order([key, subs1])
                s = m.get([key, subs1])
                if search in s:
                    found.append({{"key":[key, subs1], "content": s}})
                if subs1 == None:
                    lvl1 = False
                    break
                if (m.data([key, subs1]) > 0):
                    lvl2 = True
                    subs2 = ''
                    while (lvl2):
                        subs2 = m.order([key, subs1, subs2])
                        if subs2 == None:
                            lvl2 = False
                            break
                        s = m.get([key, subs1, subs2])
                        if search in s:
                            found.append({{"key":[key, subs1, subs2], "content": s}})
    df = pd.DataFrame(data=found, columns=["key","content"])
    return json.dumps(df.to_json())
}}
```

### Sample Output Json expected:
```json
{{"key":["AL","West","1"],"content":"Houston"}}
```

"""
}

}
