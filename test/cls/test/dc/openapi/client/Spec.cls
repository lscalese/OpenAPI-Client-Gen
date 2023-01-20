Class test.dc.openapi.client.Spec Extends %UnitTest.TestCase
{

Method GetBaseTestDir(Output separator As %String) As %String
{
    Set separator = $s($$$isWINDOWS:"\",1:"/")
    // currentdir will be repo_root/test/cls/YAML/Test/
    Quit $piece(..Manager.CurrentDir, separator, 1, *-6)_separator
}

Method TestGenerateProduction() As %Status
{
    #dim sc As %Status = $$$OK
    #dim inputFile As %String
    #dim base As %String = ..GetBaseTestDir(.separator) _ "files" _ separator

    Set app("zzzpetshop") = base _ "petshop.json"
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

Method TestSwaggerModel() As %Status
{
    #dim sc As %Status = $$$OK
    #dim base As %String = ..GetBaseTestDir(.separator) _ "files" _ separator
    #dim file As %String = base _ "swagger-test.json"

    
    #dim appName As %String = "zzzswaggertest"

    Set classExists( appName _ ".Production") = ""
    Set classExists( appName _ ".Utils") = ""
    Set classExists( appName _ ".bo.Operation") = ""
    Set classExists( appName _ ".bp.Process") = ""
    Set classExists( appName _ ".bp.SyncProcess") = ""
    Set classExists( appName _ ".bs.ProxyService") = ""

    Set classExists( appName _ ".responses.GenericResponse") = ""
    
    Set classExists( appName _ ".model.spec" ) = ""


    TSTART
    Try {
        Set sc = ##class(dc.openapi.client.Spec).generateApp( appName , file )
        Do $$$AssertStatusOK( sc , "Generate Swagger Test" )

        #dim class As %String = ""

        For  {

            Set class = $Order(classExists( class ) )
            Quit:class=""

            Do $$$AssertTrue( ''$$$defClassDefined(class) , $$$FormatText("Class %1 exists", class ) )

        }

        Set class = ""
        For  {
            Set class = $Order(propertyCheck( class ) )
            Quit:class=""

            Set propertyName = ""
            For  {
                Set propertyName = $Order( propertyCheck( class, propertyName ) )
                Quit:propertyName=""

                Merge attributes = propertyCheck( class, propertyName )

                Do $$$AssertStatusOK( ..checkProperty( class, propertyName, .attributes ), $$$FormatText("Check Class property %1.%2", class, propertyName ) )
                Kill attributes
            }
        }

        Set methodId = ""
        For  {
            Set methodId = $Order(methodExists( methodId ) )
            Quit:methodId=""
            
            Merge attributes = methodExists( methodId )
            
            Do $$$AssertStatusOK( ..CheckMethod( methodId , .attributes ), $$$FormatText("Check Method %1", $Replace(methodId, "||", ":")  ) )
            Kill attributes
        }

        

    } Catch (ex) {
        Set sc = ex.AsStatus()
    }
    TROLLBACK

    Do $$$AssertStatusOK( sc , "TestSwaggerModel" )

    Quit sc
}

ClassMethod checkProperty(class As %String, name As %String, attribute As %Binary) As %Status
{
    #dim sc As %Status = $$$OK
    Set property = ##class(%Dictionary.PropertyDefinition).%OpenId( class _ "||" _ name , , .sc )
    Quit:$$$ISERR(sc) sc

    Set key = ""
    For  {
        
        Set key = $Order(attribute( key ), 1, attrValue )
        Quit:key=""

        If $Property( property, key ) '= attrValue {
            Return $$$ERROR($$$GeneralError, $$$FormatText("Something wrong with %1 and value %2 (expected %3)", key, $Property( property, key ), attrValue ))
        }
    }

    Quit sc
}

ClassMethod CheckMethod(methodId As %String, attribute As %Binary) As %Status
{
    #dim sc As %Status = $$$OK

    Set method = ##class(%Dictionary.MethodDefinition).%OpenId( methodId, , .sc)
    Quit:$$$ISERR(sc) sc

    Set key = ""
    For  {
        
        Set key = $Order(attribute( key ), 1, attrValue )
        Quit:key=""

        If $Property( method , key ) '= attrValue {
            Return $$$ERROR($$$GeneralError, $$$FormatText("Something wrong with Method %1, attribute %2 with value %3 (expected %4)", $Replace(methodId, "||", ":"), key, $Property( method, key ), attrValue ))
        }
    }

    Quit sc
}

}
