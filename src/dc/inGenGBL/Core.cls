Class dc.inGenGBL.Core Extends %RegisteredObject
{

ClassMethod Split(gblName As %String, chunkSize As %Integer = 3, startAt As %String = "", Output status As %Status) As %String
{
    Set output = ""
    Set status = $$$OK
    Try {
        Set chunks = $$SplitSize^%GSIZE(gblName, "N", chunkSize, startAt)
        Set output = $ListToString($list(chunks,2),"|")
    } Catch ex {
        Set status=ex.AsStatus()
    }
    /*
    my_company = iris.cls('Sample.Company')._New()
    my_company.Name = 'Acme Widgets, Inc.'
    my_company.TaxID = '123456789'
    status = my_company._Save()
    print(status)
    print(my_company._Id())
    
    */
    Return output
}

ClassMethod Process(input As %String = "") As %String [ Language = python ]
{
    import os
    from dotenv import load_dotenv

    import iris
    import json

    # Import langchain
    from langchain_openai import ChatOpenAI
    from langchain.prompts import ChatPromptTemplate
    from langchain.chains import LLMChain
    from langchain.chains.router import MultiPromptChain
    from langchain.chains.router.llm_router import LLMRouterChain, RouterOutputParser
    from langchain.prompts import PromptTemplate

    load_dotenv()

    llm = ChatOpenAI(model= "gpt-3.5-turbo", temperature=0, api_row=os.getenv('OPENAI_API_KEY'))

    # Define specialized prompt templates
    mapping_template = """You are an InterSystems Multi-Model expert and a global mapping specialist.\
I will provide you with a global name, the main subscript, and the separator used. \
Your task is to analyze the structure and identify the number of pieces in each node, \
as well as the data type of each piece.

You must create a Python ClassMethod as follows:

### Input:
- **Global name**: For example, `"^mapping"`.
- **Subscript**: Provided by the user, such as `"Less Simple,1"`.
- **Separator**: Provided by the user (e.g., `","`), defaulting to a caret (`"^"`).

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
ClassMethod MappingGlobal(name, subscript, separator="^") As %Status [ Language = python ]
{
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
        return {"error": "Invalid subscript provided"}

    # Initialize global and variables
    try:
        mapping = iris.gref(name)
    except Exception as e:
        return {"error": str(e)}

    delimiter = separator if separator else "^"
    json_obj = {
        "Storage": {
            "Type": "%CacheSQLStorage",
            "StreamLocation": "^Mapping.Example2S",
            "SQLMap": {
                "Type": "data",
                "Global": name,
                "Subscript": [],
                "Data": [],
                "_name": "Map1"
            },
            "_name": "NewStorage1"
        }
    }

    # Parse subscript structure
    subscripts = subscript.split(",")
    for idx, subs in enumerate(subscripts):
        json_obj["Storage"]["SQLMap"]["Subscript"].append({
            "Expression": subs,
            "_name": str(idx + 1)
        })

    # Sample records to determine data types
    sample_count = 100
    key = ""
    content = []

    for _ in range(sample_count):
        row = {}
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
    keys_type = {}
    data_type = []

    for item in content:
        key_type = item['key']
        keys_type[key_type] = keys_type.get(key_type, 0) + 1

        for index, dataItem in enumerate(item["data"]):
            if len(data_type) <= index:
                data_type.append({})
            dataItem_type = dataItem
            if dataItem_type not in data_type[index]:
                data_type[index][dataItem_type] = 0
            data_type[index][dataItem_type] += 1

    # Assign the most frequent data type for subscripts and fields
    json_obj['Storage']['SQLMap']['Subscript'][2]['_type'] = max(keys_type, key=keys_type.get)
    for index in range(len(data_type)):
        dtype = max(data_type[index], key=data_type[index].get)
        json_obj['Storage']['SQLMap']['Data'].append({
            "Delimiter": delimiter,
            "Piece": index + 1,
            "_name": "col" + str(index),
            "_type": dtype
        })

    return json.dumps(json_obj)
}
```

    Here is a task:
    {input}
    
    """


    # Create prompt info dictionaries
    prompt_infos = [
        {
            "name": "mapping",
            "description": "Good for tasks about mapping globals",
            "prompt_template": mapping_template,
        },
    ]

    # Create destination chains (LLMChains) for each prompt
    destination_chains = {}
    for p_info in prompt_infos:
        name = p_info["name"]
        prompt_template = p_info["prompt_template"]
        prompt = ChatPromptTemplate.from_template(template=prompt_template)
        chain = LLMChain(llm=llm, prompt=prompt)
        destination_chains[name] = chain

    destinations = [f"{p['name']}: {p['description']}" for p in prompt_infos]
    destinations_str = "\n".join(destinations)

    # Define a default chain for inputs that don't match any specialized prompt
    default_prompt = ChatPromptTemplate.from_template("{input}")
    default_chain = LLMChain(llm=llm, prompt=default_prompt)

    MULTI_PROMPT_ROUTER_TEMPLATE = """Given a raw text input to a \
    language model select the model prompt best suited for the input. \
    You will be given the names of the available prompts and a \
    description of what the prompt is best suited for. \
    You may also revise the original input if you think that revising\
    it will ultimately lead to a better response from the language model.

    << FORMATTING >>
    Return a string snippet enclosed by triple backticks a JSON object formatted to look like below:
    {
        "destination": string \ name of the prompt to use or "default"
        "next_inputs": string \ a potentially modified version of the original input
    }

    REMEMBER: "destination" MUST be one of the candidate prompt \
    names specified below OR it can be "default" if the input is not \
    well suited for any of the candidate prompts. \
    REMEMBER: "next_inputs" can just be the original input \
    if you don't think any modifications are needed.

    << CANDIDATE PROMPTS >>
    {destinations}

    REMEMBER: If destination name not there input the task

    << INPUT >>
    {input}

    << OUTPUT (remember to include the ```

    json

    ```)>>"""

    try:

        # Create the router prompt template
        router_template = MULTI_PROMPT_ROUTER_TEMPLATE.format(destinations=destinations_str)  # (a prompt template for the router to use)
        router_prompt = PromptTemplate(template=router_template, input_variables=["input"], output_parser=RouterOutputParser())
        router_chain = LLMRouterChain.from_llm(llm, router_prompt)

        # Create the MultiPromptChain
        chain = MultiPromptChain(
            router_chain=router_chain,
            destination_chains=destination_chains,
            default_chain=default_chain,
            verbose=True,
        )

        result = chain.invoke("help to mapping a global called glbs with caret as separator")
    except Exception as err:
        print( str(err))
        return {"error": str(err)}



    return json.dumps(result)
}

}
