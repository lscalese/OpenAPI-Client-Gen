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

    
    #dim appName As %String = "zzzswaggertest"

    Set classExists( appName _ ".Production") = ""
    Set classExists( appName _ ".Utils") = ""
    Set classExists( appName _ ".bo.Operation") = ""
    Set classExists( appName _ ".bp.Process") = ""
    Set classExists( appName _ ".bp.SyncProcess") = ""
    Set classExists( appName _ ".rest.Projection") = ""
    Set classExists( appName _ ".rest.REST") = ""
    Set classExists( appName _ ".bs.ProxyService") = ""

    Set classExists( appName _ ".msg.GenericResponse") = ""
    Set classExists( appName _ ".msg.ParsedResponse" ) = ""
    
    Set classExists( appName _ ".model.spec" ) = ""
    Set classExists( appName _ ".model.Definition.nestedobject" ) = ""
    Set classExists( appName _ ".model.Definition.object1" ) = ""
    Set classExists( appName _ ".model.Definition.nestedSchemaAnonymous") = ""

    

    ; POST /nestedobject  
    Set classExists( appName _ ".msg.postnestedobjectRequest" ) = ""

    Set propertyCheck( appName _ ".msg.postnestedobjectRequest", "accept", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.postnestedobjectRequest", "consume", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.postnestedobjectRequest", "bodynestedobject", "Type" ) = appName _ ".model.Definition.nestedobject"    

    

    ; model.Definition.nestedobject check;
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listInteger", "Type" ) = "%Integer"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listInteger", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listObject1", "Type" ) = "object1"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "listObject1", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "nestedSchema", "Type" ) = "nestedSchemaAnonymous"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "simpleObject1", "Type" ) = "object1"
    Set propertyCheck( appName _ ".model.Definition.nestedobject", "simpleString", "Type" ) = "%String"
    
    ; model.Definition.object1 check
    Set propertyCheck( appName _ ".model.Definition.object1", "property", "Type" ) = "%Integer"
   
    ; nestedSchemaAnonymous check
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSchemaObject1", "Type" ) = "object1"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSchemaObject1", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSimpleString", "Type" ) = "%String"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "ListSimpleString", "Collection" ) = "list"
    Set propertyCheck( appName _ ".model.Definition.nestedSchemaAnonymous", "SchemaObject1", "Type" ) = "object1"

    ; GET /firstservice/{id} operation Id FirstServiceId

    Set classExists( appName _ ".msg.FirstServiceIdRequest" ) = ""
    Set classExists( appName _ ".msg.FirstServiceIdResponse" ) = ""
    Set classExists( appName _ ".bs.FirstServiceIdService" ) = ""

    Set propertyCheck( appName _ ".msg.FirstServiceIdRequest", "pathid", "Type" ) = "%Integer"
    Set propertyCheck( appName _ ".msg.FirstServiceIdRequest", "consume", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.FirstServiceIdRequest", "accept", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.FirstServiceIdRequest", "headerheaderTest", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.FirstServiceIdResponse", "object1", "Type" ) = appName _ ".model.Definition.object1"
    Set propertyCheck( appName _ ".msg.FirstServiceIdResponse", "listobject1", "Type" ) = appName _ ".model.Definition.object1"
    Set propertyCheck( appName _ ".msg.FirstServiceIdResponse", "listobject1", "Collection" ) = "list"
    

    ; POST /firstservice generated operation ID : postfirstservice

    Set classExists( appName _ ".msg.postfirstserviceRequest" ) = ""
    Set classExists( appName _ ".bs.postfirstserviceService" ) = ""

    Set propertyCheck( appName _ ".msg.postfirstserviceRequest", "consume", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.postfirstserviceRequest", "accept", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.postfirstserviceRequest", "bodyname", "Type" ) = appName _ ".model.Definition.object1"

    ; GET /withallof operation ID : GetWithAllOf

    Set classExists( appName _ ".msg.GetWithAllOfRequest" ) = ""
    Set classExists( appName _ ".msg.GetWithAllOfResponse" ) = ""
    Set classExists( appName _ ".bs.GetWithAllOfService" ) = ""
    Set classExists( appName _ ".model.Definition.testSimpleAllOf" ) = ""
    Set classExists( appName _ ".model.Definition.nested201AllOf" ) = ""
    Set classExists( appName _ ".model.Definition.nested204ArrayAllOf" ) = ""
    
    Set propertyCheck( appName _ ".model.Definition.testSimpleAllOf", "additionalInfo1", "Type" ) = "%String"
    Set propertyCheck( appName _ ".model.Definition.testSimpleAllOf", "additionalInfo2", "Type" ) = "%String"
    Set propertyCheck( appName _ ".model.Definition.nested201AllOf", "allOf201AddInfo", "Type" ) = "%String"
    Set propertyCheck( appName _ ".msg.GetWithAllOfResponse", "testSimpleAllOf", "Type" ) = appName _ ".model.Definition.testSimpleAllOf"
    Set propertyCheck( appName _ ".msg.GetWithAllOfResponse", "nested201AllOf", "Type" ) = appName _ ".model.Definition.nested201AllOf"

    Set propertyCheck( appName _ ".msg.GetWithAllOfResponse", "listnested204ArrayAllOf", "Type" ) = appName _ ".model.Definition.nested204ArrayAllOf"
    Set propertyCheck( appName _ ".msg.GetWithAllOfResponse", "listnested204ArrayAllOf", "Collection" ) = "list"
    Set propertyCheck( appName _ ".msg.GetWithAllOfRequest", "bodyallOfParameters", "Type" ) = appName _ ".model.Definition.allOfParameters"

    ; POST /withallof operation ID : PostWithAllOf

    Set classExists( appName _ ".msg.PostWithAllOfRequest" ) = ""
    Set classExists( appName _ ".bs.PostWithAllOfService" ) = ""
    Set classExists( appName _ ".model.Definition.NestedallOfParameters" ) = ""
    
    Set propertyCheck( appName _ ".msg.PostWithAllOfRequest", "bodyNestedallOfParameters", "Type" ) = appName _ ".model.Definition.NestedallOfParameters"
    Set propertyCheck( appName _ ".model.Definition.NestedallOfParameters", "aFieldInAllOf2", "Type" ) = "%String"

    ; PUT /withallof operation ID : PutWithAllOf

    Set classExists( appName _ ".msg.PutWithAllOfRequest" ) = ""
    Set classExists( appName _ ".bs.PutWithAllOfService" ) = ""
    Set classExists( appName _ ".model.Definition.ListNestedallOfParameters" ) = ""
    
    Set propertyCheck( appName _ ".msg.PutWithAllOfRequest", "bodyListNestedallOfParameters", "Type" ) = appName _ ".model.Definition.ListNestedallOfParameters"
    Set propertyCheck( appName _ ".model.Definition.ListNestedallOfParameters", "aFieldInAllOf3", "Type" ) = "%String"
    

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
