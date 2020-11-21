Class test.dc.openapi.client.SpecTransform Extends %UnitTest.TestCase
{

Parameter INPUTFILES = "petshop.json,nlp.json,nlp.yaml,swagger-test.json";

Method GetBaseTestDir(Output separator As %String) As %String
{
    Set separator = $s($$$isWINDOWS:"\",1:"/")
    // currentdir will be repo_root/test/cls/YAML/Test/
    Quit $piece(..Manager.CurrentDir, separator, 1, *-6)_separator
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
    #dim outDir As %String = baseDir _ "out/transform/"

    
    Do:##class(%File).DirectoryExists( outDir ) ##class(%File).RemoveDirectoryTree( outDir )
    
    Set writeAccess = ##class(%File).CreateDirectoryChain( outDir )
    
    
    Try {

        For  {
            
            Set inputFile = $Piece( ..#INPUTFILES, ",", $Increment(i))
            Quit:inputFile=""
            
            Set filePath = baseDir _ inputFile
            Set spec = ##class(dc.openapi.client.Spec).loadSpecFromFile( filePath )

            Set specTransformer = ##class(dc.openapi.client.SpecTransform).%New( spec )
            Set simplifiedSpec = specTransformer.transform( .sc )

            Do $$$AssertTrue( $Isobject(simplifiedSpec), "transform return an object." )

            Do $$$AssertStatusOK( sc, "transform " _filePath)

            If $Isobject(simplifiedSpec) && writeAccess {   ; dump json only if we can write.
                
                Set stream=##class(%FileCharacterStream).%New()
                Set stream.TranslateTable="UTF8"
                Set stream.Filename = outDir _ $Piece(inputFile , ".", *-1) _ ".json"
                Set formatter=##class(%JSON.Formatter).%New()
                $$$ThrowOnError(formatter.FormatToStream(simplifiedSpec, .stream))
                $$$ThrowOnError(stream.SaveStream())
                Kill stream

            }
        }

    } Catch (ex) {
        
        Set sc = ex.AsStatus()
        Do $$$AssertStatusOK( sc , "TestTransform")
       
    }

    Quit sc
}

}
