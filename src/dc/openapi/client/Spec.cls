Class dc.openapi.client.Spec Extends %RegisteredObject
{

Parameter XDataName = "OpenAPI";

XData OpenAPI [ MimeType = application/json ]
{
{ "swagger":"2.0" }
}

/// Generate the client classes<br/>
/// Specify your application package in appName argument.<br/>
/// spec is the open api 2.0 specification in JSON Format<br/>
/// It could be a stream, a dynamic object or an URL.<br/>
/// ex: Set sc = ##class(dc.openapi.client.Spec).generateApp("petstore", "https://petstore.swagger.io:443/v2/swagger.json")
ClassMethod generateApp(appName As %String, spec) As %Status
{
    If $Isobject(spec) {
        If spec.%IsA("%Stream.Object") {
            Set spec = {}.%FromJSON(.spec)
        }
    } Else {
        If $ZCONVERT($Extract(spec, 1, 4), "l") = "http" {
            Set spec = ..loadSpecFromUrl(spec)
        } Else {
            Set spec = ..loadSpecFromFile(spec)
        }
    }

    Return ..%CreateClientApplication(appName, spec)
}

ClassMethod loadSpecFromFile(file As %String) As %DynamicObject
{
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set stream.Filename = file
    Set spec = {}.%FromJSON(.stream)
    Return spec
}

ClassMethod loadSpecFromUrl(url As %String) As %DynamicObject
{
    Set request = ##class(%Net.HttpRequest).%New()
    Set request.Server = $Piece($Piece(url,"/",3),":",1)
    Set request.Port = $Piece($Piece(url,"/",3),":",2)
    Set protocol = $Zcvt($Piece(url,":",1),"l")
    Set request.Https = (protocol="https")
    
    If request.Https {
        Set request.SSLConfiguration = "default"
    }

    $$$TOE(sc, request.Send("GET", $Piece(url,"/",4,*)))
    
    If request.HttpResponse.StatusCode '= 200 {
        $$$ThrowStatus($$$ERROR(5001, "Http status code : " _ request.HttpResponse.StatusCode ))
    }

    Return {}.%FromJSON(request.HttpResponse.Data)
}

ClassMethod %CreateClientApplication(applicationName As %String, swagger As %DynamicObject, ByRef features, Output newApplication As %Boolean) As %Status
{
    Set sc = $$$OK
   
    TStart 
    Try {
        
        Set specClass = applicationName _ ".spec"
        Set clientClass = applicationName _ ".client"

        /// Create or update a class with Open Api specification

        Set cDef=##class(%Dictionary.ClassDefinition).%OpenId(specClass,4,.sc)
        
        If $Isobject(cDef) {
            Do ..%RemoveXDataBlock(cDef,..#XDataName)
            Set newApplication=0
        } Else {
            Set cDef=##class(%Dictionary.ClassDefinition).%New(specClass)
            Set newApplication=1
        }

        Set cDef.Super = "dc.openapi.client.Spec"
        Set cDef.ProcedureBlock=1

        Set xData=##class(%Dictionary.XDataDefinition).%New()
        Set xData.Name=..#XDataName
        Set xData.MimeType="application/json"

        
        Set formatter=##class(%JSON.Formatter).%New()
        $$$TOE(sc, formatter.FormatToString(swagger, .swaggerString))
        
        $$$TOE(sc, xData.Data.Write(swaggerString))
        $$$TOE(sc, cDef.XDatas.Insert(xData))
        $$$TOE(sc, cDef.%Save())
        
        Do $system.OBJ.Delete(clientClass,"-d")
        Write !,"Compile ",specClass
        $$$TOE(sc, $system.OBJ.Compile(specClass,"ck-d"))
        Write !,"Compile ",sc

    } Catch (ex) {
        Set sc = ex.AsStatus()
    }

    If $$$ISOK(sc) {
        TCommit 
    } Else {
        TROllback 1
    }
    
    Return sc
}

ClassMethod %OnCompile() [ CodeMode = objectgenerator, ForceGenerate ]
{
    ;Write !,"%OnCompile"
	// Don't run this method on the base class
	Set classname=%compiledclass.Name
	Return:classname="dc.openapi.client.Spec" $$$OK

	Set sc=$$$OK

    Set xdata = ##class(%Dictionary.XDataDefinition).%OpenId( classname _ "||OpenAPI" )
    Set spec = {}.%FromJSON(xdata.Data)
    Set generator = ##class(dc.openapi.client.Generator).%New()
    Set generator.spec = spec
    Set generator.application = $Piece(classname, ".", 1, *-1)
    ;W !,$SYSTEM.Status.GetOneErrorText(generator.generate())
    Set sc = generator.generate()
	Quit sc
}

ClassMethod %RemoveXDataBlock(cDef, blockName)
{
 	Set key = cDef.XDatas.FindObjectId(cDef.Name_"||"_blockName)
 	If (key'="") {
 		Set oid = cDef.XDatas.RemoveAt(key)
	}
}

}
