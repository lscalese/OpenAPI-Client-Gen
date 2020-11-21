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
    ;Set app("zzzdocconverter") = base _ "zdoc.json"
    
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

    
    Set appName = "zzzswaggertest"

    Set classExists( appName _ ".msg.postnestedobjectRequest" ) = ""
    Set classExists( appName _ ".model.Definition.nestedobject" ) = ""
    Set classExists( appName _ ".model.Definition.object1" ) = ""
    Set classExists( appName _ ".model.Definition.nestedSchemaAnonymous") = ""
    Set classExists( appName _ ".bo.Operation") = ""
    Set classExists( appName _ ".bp.Process") = ""
    Set classExists( appName _ ".bp.SyncProcess") = ""
    Set classExists( appName _ ".Production") = ""
    Set classExists( appName _ ".Utils") = ""
    Set classExists( appName _ ".rest.Projection") = ""
    Set classExists( appName _ ".rest.REST") = ""
    Set classExists( appName _ ".msg.GenericResponse") = ""
    Set classExists( appName _ ".bs.ProxyService") = ""

    Set propertyCheck( appName _ ".msg.postnestedobjectRequest", "accept", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.postnestedobjectRequest", "consume", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.postnestedobjectRequest", "bodynestedobject", "Type" ) = appName _ ".model.Definition.nestedobject"

    Set propertyCheck( appName _ ".msg.FirstServiceIdRequest", "pathid", "Type" ) = "%Integer"
    Set propertyCheck( appName _ ".msg.FirstServiceIdRequest", "headerheaderTest", "Type" ) = "%String"
    

    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listInteger", "Type" ) = "%Integer"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listInteger", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listObject1", "Type" ) = "object1"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listObject1", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "nestedSchema", "Type" ) = "nestedSchemaAnonymous"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "simpleObject1", "Type" ) = "object1"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "simpleString", "Type" ) = "%String"
    
    Set propertyCheck( appName _ ".model.Definition.object1", "property", "Type" ) = "%Integer"
   
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSchemaObject1", "Type" ) = "object1"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSchemaObject1", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSimpleString", "Type" ) = "%String"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSimpleString", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "SchemaObject1", "Type" ) = "object1"


    
    

    Set prop = ##class(%Dictionary.PropertyDefinition).%Exists()
    TSTART
    Try {
        Set sc = ##class(dc.openapi.client.Spec).generateApp( appName , file )
        Do $$$AssertStatusOK( sc , "Generate Swagger Test" )

        Set class = ""
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

                Kill attributes
                Merge attributes = propertyCheck( class, propertyName )

                Do $$$AssertStatusOK( ..checkProperty( class, propertyName, .attributes ), $$$FormatText("Check Class property %1.%2", class, propertyName ) )
            }
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

}
