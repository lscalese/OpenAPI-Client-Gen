Include dc.openapi.common.macro

Class dc.openapi.client.Spec Extends %RegisteredObject
{

Parameter XDataName = "OpenAPI";

XData OpenAPI [ MimeType = application/json ]
{
{  }
}

/// Generate the client classes<br/>
/// Specify your application package in appName argument.<br/>
/// spec is the open api 2.0 specification in JSON Format<br/>
/// It could be a stream, a dynamic object or an URL.<br/>
/// ex: Set sc = ##class(dc.openapi.client.Spec).generateApp("petstore", "https://petstore.swagger.io:443/v2/swagger.json")
ClassMethod generateApp(appName As %String, spec, features As %Binary) As %Status
{

    Set sc = $$$OK
    
    Set spec = ##class(dc.openapi.common.SpecificationLoader).AbstractSpecLoader(spec, .sc)
    Quit:$$$ISERR(sc) sc

    Return ..%CreateClientApplication(appName, spec, .features)
}

ClassMethod %CreateClientApplication(applicationName As %String, swagger As %DynamicObject, ByRef features, Output newApplication As %Boolean) As %Status
{
    Set sc = $$$OK
   
    Try {
        
        Set specClass = applicationName _ ".model.spec"
        $$$zlog("* Create a class with the specification in a XData block " _ specClass)
        
        Set cDef=##class(%Dictionary.ClassDefinition).%OpenId(specClass,4,.sc)
        
        If $Isobject(cDef) {
            Do ..%RemoveXDataBlock(cDef,..#XDataName)
            Set newApplication = $$$NO

        } Else {

            Set cDef=##class(%Dictionary.ClassDefinition).%New(specClass)
            Set newApplication = $$$YES

        }

        ; Security to avoid overwrite an existing package on the server ...
        If newApplication && ..packageExists(applicationName)  { 
            
            Set sc = $$$ERROR(5001, "Overwritting code protection.  This package already exist on the server, please choose an other appName "_applicationName)
            $$$ThrowStatus(sc)
        }

        Set cDef.Super = "%RegisteredObject"
        Set cDef.ProcedureBlock = $$$YES

        Set xData = ##class(%Dictionary.XDataDefinition).%New()
        Set xData.Name = ..#XDataName
        Set xData.MimeType = "application/json"

        ; keep the last transformed swagger (debug purpose)
        Set ^CacheTemplsc(1) = swagger.%ToJSON()
        Kill transformer
        
        $$$ThrowOnError(##class(%JSON.Formatter).%New().FormatToStream(swagger, xData.Data))
        $$$ThrowOnError(cDef.XDatas.Insert(xData))
        $$$ThrowOnError(cDef.%Save())
        $$$ThrowOnError($system.OBJ.Compile(specClass,"ck"))

        Do ##class(community.utils.SSLClient).CreateSSLConfiguration("DefaultSSL")

        If $Get(features("simpleHttpClientOnly")) = 1 {
            Set generator = ##class(dc.openapi.client.HttpClientGenerator).%New(swagger, applicationName)
            Set sc = generator.GenerateClient()
        } Else {
            Set generator = ##class(dc.openapi.client.ProductionGenerator).%New(swagger, applicationName)
            Set sc = generator.Generate()
        }

    } Catch (ex) {
        Set sc = ex.AsStatus()
    }

    If $$$ISOK(sc), $Get(features("compile"), 1) {
        ; no error -> compile
        Set sc = $SYSTEM.OBJ.CompilePackage(applicationName)
    }
    
    Return sc
}

ClassMethod %RemoveXDataBlock(cDef, blockName)
{
 	Set key = cDef.XDatas.FindObjectId(cDef.Name_"||"_blockName)
 	If (key'="") {
 		Set oid = cDef.XDatas.RemoveAt(key)
	}
}

/// Check if a package exists on server ...
ClassMethod packageExists(packageName As %String) As %Boolean
{
    Set packageList = ##class(%Dictionary.PackageDefinition).GetPackageList()
    Return ''packageList.Find($zcvt(packageName, "U"))
}

}
