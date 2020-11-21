Class test.dc.openapi.client.Spec Extends %UnitTest.TestCase
{

Method GetBaseTestDir(Output separator As %String) As %String
{
    Set separator = $s($$$isWINDOWS:"\",1:"/")
    // currentdir will be repo_root/test/cls/YAML/Test/
    Quit $piece(..Manager.CurrentDir, separator, 1, *-5)_separator
}

Method TestGenerateProduction() As %Status
{
    #dim sc As %Status = $$$OK
    #dim inputFile As %String
    #dim base As %String = ..GetBaseTestDir(.separator) _ "files" _ separator

    Set app("zzzpetshop") = base _ "petshop.json"
    Set app("zzzdocconverter") = base _ "zdoc.json"
    

    Set appName = ""
    
    For  {

        Set appName = $Order(app(appName), 1, file )
        Quit:appName="" 

        Do $$$LogMessage( $$$FormatText("Attempt to generate %1 production", appName) )
        
        TSTART
        Try {
            Set sc = ##class(dc.openapi.client.Spec).generateApp( appName, file )
        } Catch (ex) {
            Set sc = ex.AsStatus()
        }
        TROLLBACK
        
        Do $$$AssertStatusOK( sc , "Generate " _ appName )

    }
    Quit sc
}

}
