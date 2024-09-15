Class dc.sample.mapping Extends %RegisteredObject
{

ClassMethod populateHero()
{
    Set ^glbs($I(^glbs))="Steve Rogers^Captain America^Avenger"
    Set ^glbs($I(^glbs))="Tony Stark^Iron Man^Avenger"
    Set ^glbs($I(^glbs))="Thor Odinson^Thor^Avenger"
    Set ^glbs($I(^glbs))="Natasha Romanoff^Black Widow^Avenger"
    Set ^glbs($I(^glbs))="Bruce Banner^Hulk^Avenger"
    Set ^glbs($I(^glbs))="Clint Barton^Hawkeye^Avenger"
    Set ^glbs($I(^glbs))="Peter Parker^Spider-Man^Avenger"
    Set ^glbs($I(^glbs))="T'Challa^Black Panther^Avenger"
    Set ^glbs($I(^glbs))="Carol Danvers^Captain Marvel^Avenger"
    Set ^glbs($I(^glbs))="Scott Lang^Ant-Man^Avenger"
    Set ^glbs($I(^glbs))="Bruce Wayne^Batman^Justice League"
    Set ^glbs($I(^glbs))="Clark Kent^Superman^Justice League"
    Set ^glbs($I(^glbs))="Diana Prince^Wonder Woman^Justice League"
    Set ^glbs($I(^glbs))="Barry Allen^The Flash^Justice League"
    Set ^glbs($I(^glbs))="Hal Jordan^Green Lantern^Justice League"
    Set ^glbs($I(^glbs))="Arthur Curry^Aquaman^Justice League"
    Set ^glbs($I(^glbs))="J'onn J'onzz^Martian Manhunter^Justice League"
    Set ^glbs($I(^glbs))="Oliver Queen^Green Arrow^Justice League"
    Set ^glbs($I(^glbs))="Victor Stone^Cyborg^Justice League"
    Set ^glbs($I(^glbs))="Dinah Lance^Black Canary^Justice League"
}

ClassMethod pop()
{
    Set ^mapping("Less Simple",1,1)="Bannon,Brendan^Father"
    Set ^mapping("Less Simple",1,1,"Activity")="Rock Climbing"
    Set ^mapping("Less Simple",1,2)="Bannon,Sharon^Mother"
    Set ^mapping("Less Simple",1,2,"Activity")="Yoga"
    Set ^mapping("Less Simple",1,3)="Bannon,Kaitlin^Daughter"
    Set ^mapping("Less Simple",1,3,"Activity")="Lighting Design"
    Set ^mapping("Less Simple",1,4)="Bannon,Melissa^Daughter"
    Set ^mapping("Less Simple",1,4,"Activity")="Marching Band"
    Set ^mapping("Less Simple",1,5)="Bannon,Robin^Daughter"
    Set ^mapping("Less Simple",1,5,"Activity")="reading"
    Set ^mapping("Less Simple",1,6)="Bannon,Kieran^Son"
    Set ^mapping("Less Simple",1,6,"Activity")="Marching Band"
}

ClassMethod MappingGlobal() As %Status [ Language = python ]
{
    import iris
    import json

    def dataType_identify(value):
        if isinstance(value, (int, float)) or (isinstance(value, str) and '.' in value and value.replace('.', '').isdigit()):
            dataType = "%Numeric"
        elif isinstance(row, str):
            if row.isdigit() and len(row) == 5:
                dataType = "%Date"
            elif ',' in row and all(part.isdigit() and len(part) == 5 for part in row.split(',')):
                row_type = "%DateTime"
            elif row.isdigit():
                dataType = "%Integer"
            else:
                dataType = "%String"
        else:
            dataType = "%String"

        return dataType

    mapping = iris.gref('^mapping')
    delimiter = "^"
    json_obj = {
            "Storage": {
                "Type": "%CacheSQLStorage",
                "StreamLocation": "^Mapping.Example2S",
                "SQLMap": {
                    "Type": "data",
                    "Global": "^mapping",
                    "Subscript": [
                        {
                            "Expression": '"Less Simple"',
                            "_name": "1"
                        },
                        {
                            "Expression": "1",
                            "_name": "2"
                        },
                        {
                            "Expression": "{rowIdentificator}",
                            "_name": "3"
                        }
                    ],
                    "Data": [],
                    "_name": "Map1"
                },
                "_name": "NewStorage1"
            }
        }
    key = ""

    content = []

    while True:
        row = {}
        key = mapping.order(["Less Simple",1,key])
        if key is None:
            break
        row["key"] = dataType_identify(key)

        reg = mapping.get(["Less Simple",1,key])
        data = []
        columns = reg.split(delimiter)
        for column in columns:
            data.append(dataType_identify(column))

        k = ''
        if (mapping.data(["Less Simple",1,key]) > 0):
            for (k, value) in mapping.orderiter(["Less Simple",1,key, k]):
                data.append(k[-1])
        row["data"] = data
        content.append(row)
    # Analisando os tipos de dados em content
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
        
    json_obj['Storage']['SQLMap']['Subscript'][2]['_type'] = max(keys_type, key=keys_type.get)
    for index in range(0,len(data_type)):
        dtype = max(data_type[index], key=data_type[index].get)
        if dtype in ["%String","%Numeric","%DateTime","%Date","%Integer"]:
            json_obj['Storage']['SQLMap']['Data'].append({
                "Delimiter": delimiter,
                "Piece": index + 1,
                "_name": "col"+str(index),
                "_type": dtype
            })
        else:
            json_obj['Storage']['SQLMap']['Data'].append({
                "Delimiter": delimiter,
                "Node": dtype,
                "Piece": 1,
                "_name": "col"+str(index)
            })
    print(json.dumps(json_obj))


    return True
}

}
