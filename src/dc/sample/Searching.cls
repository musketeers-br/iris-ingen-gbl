Class dc.sample.Searching Extends %RegisteredObject
{

ClassMethod SearchingGlobal() As %Status [ Language = python ]
{
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
            found.append({"key":[key], "content": s})
        if (m.data([key]) > 0):
            lvl1 = True
            subs1 = ''
            while (lvl1):
                subs1 = m.order([key, subs1])
                s = m.get([key, subs1])
                if search in s:
                    found.append({"key":[key, subs1], "content": s})
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
                            found.append({"key":[key, subs1, subs2], "content": s})
    df = pd.DataFrame(data=found, columns=["key","content"])
    return json.dumps(df.to_json())
}

ClassMethod Populate() As %Status
{
    Set ^mlb = "Major League Baseball"
    Set ^mlb("AL") = "American League"
    Set ^mlb("AL","Central") = "AL Central"
    Set ^mlb("AL","East") = "AL East"
    Set ^mlb("AL","East",1) = "Baltimore"
    Set ^mlb("AL","East",2) = "Boston"
    Set ^mlb("AL","East",3) = "NY Yankees"
    Set ^mlb("AL","East",4) = "Tampa Bay"
    Set ^mlb("AL","East",5) = "Toronto"
    Set ^mlb("AL","West") = "AL West"
    Set ^mlb("AL","West",1) = "Houston"
    Set ^mlb("AL","West",2) = "LA Angels"
    Set ^mlb("AL","West",3) = "Oakland"
    Set ^mlb("AL","West",4) = "Seattle"
    Set ^mlb("AL","West",5) = "Texas"
    Set ^mlb("NL") = "National League"
}

}
