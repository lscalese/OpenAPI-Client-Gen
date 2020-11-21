Class test.dc.openapi.client.SpecTransform Extends %UnitTest.TestCase
{

Parameter INPUTFILES = "petshop.json,nlp.json,nlp.yaml";

Method GetBaseTestDir(Output separator As %String) As %String
{
    Set separator = $s($$$isWINDOWS:"\",1:"/")
    // currentdir will be repo_root/test/cls/YAML/Test/
    Quit $piece(..Manager.CurrentDir, separator, 1, *-5)_separator
}

Method TestLoadFromFile() As %Status
{
    #dim sc As %Status = $$$OK

    #dim baseDir As %String = ..GetBaseTestDir(.separator) _ "files" _ separator

    Try {
        
        For  {
            
            Set inputFile = $Piece( ..#INPUTFILES, ",", $Increment(i))
            Quit:inputFile=""

            Set filePath = baseDir _ inputFile
            Set spec = ##class(dc.openapi.client.Spec).loadSpecFromFile( filePath )

            Do $$$LogMessage(filePath)
        }

    } Catch (ex) {

        Set sc = ex.AsStatus()

    }

    Return sc
}

Method TestTransform() As %Status
{
    #dim sc As %Status = $$$OK

    #dim baseDir As %String = ..GetBaseTestDir(.separator) _ "files" _ separator

    Try {

        For  {
            
            Set inputFile = $Piece( ..#INPUTFILES, ",", $Increment(i))
            Quit:inputFile=""
            
            Set filePath = baseDir _ inputFile
            Set spec = ##class(dc.openapi.client.Spec).loadSpecFromFile( filePath )

            Set specTransformer = ##class(dc.openapi.client.SpecTransform).%New( spec )
            Do specTransformer.transform( .sc )

            Do $$$AssertStatusOK( sc, filePath)

            If $$$ISERR(sc) $$$ThrowStatus(sc)
        }

    } Catch (ex) {
        
        Set sc = ex.AsStatus()
        Do $$$AssertStatusOK( sc , "TestTransform")
       
    }

    Quit sc
}

}
