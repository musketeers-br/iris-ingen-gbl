Class dc.inGenGBL.Utils Extends %RegisteredObject
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

    Return output
}

ClassMethod GetGlobalSize(gblName As %String, startingNode As %String = "") As %String
{
    Set output = {}
    Set status = $$$OK
    Try {
        Set directory = $Extract(##class(%SYS.Namespace).GetGlobalDest($NAMESPACE, gblName),2,*)
        Do ##class(%Library.GlobalEdit).GetGlobalSizeBySubscript(directory,$TR(gblName,"^",""), startingNode, .size)
        Set output.total = {
            "blocks": ($Get(size("Blocks","Total"))),
            "mb": ($Get(size("MB","Total")))
        }
        Set output.averageNodesPerPage = $Get(Size("AverageNodesPerPage"))
        Set lvl = $Order(size("Blocks",""))
        Set levels = []
        While (lvl '= "") {
            If (lvl = "Total") {
                Set lvl = $Order(size("Blocks",lvl))
                Continue
            }
            Set obj = {}
            Set level = {"size": ($Get(size("MB",lvl))),
                "blocks": ($Get(size("Blocks",lvl)))
            }
            Set prefix = "level_"
            Set:(lvl = "BigStrings") prefix = ""
            Do obj.%Set(prefix_lvl, level)
            Do levels.%Push(obj)
            Set lvl = $Order(size("Blocks",lvl))
        }
        Set output.levels = levels
    } Catch ex {
        Set status=ex.AsStatus()
        Set output = {"error": {"code": ($System.Status.GetErrorCodes(status)), "description": ($System.Status.GetErrorText(status))}}
    }

    Return output.%ToJSON()
}

}
