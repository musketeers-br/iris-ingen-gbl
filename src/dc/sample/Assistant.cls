Class dc.sample.Assistant Extends %RegisteredObject
{

ClassMethod Size()
{
    Set resp = ##class(dc.inGenGBL.Core).Process("what is the size of glbs global?")
    W !, resp
}

ClassMethod Map()
{
    Set resp = ##class(dc.inGenGBL.Core).Process("help to mapping a global called glbs with caret as delimiter, no subscript")
    W !, resp
}

ClassMethod Search()
{
    Set resp = ##class(dc.inGenGBL.Core).Process("search Clint Barton on glbs global with caret as delimiter")
    W !, resp
}

}
