Include dc.openapi.client.macro

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
    
    Set spec = ..AbstractSpecLoader(spec, .features, .sc)
    Quit:$$$ISERR(sc) sc

    If spec.%IsDefined("swagger") {
        ; This is not an OpenAPI 3 specification
        ; The library does not support only version 3
        ; We attempt to convert this specification to version 3 https://converter.swagger.io/
        $$$zlog("Not an OpenAPI V3 specification, try to convert using swagger converter... ")
        Set webConverter = ##class(dc.swaggerconverter.WebConverter).%New()
        Set webConverter.specification = spec
        Set sc = webConverter.Convert(.OpenAPIV3)
        Quit:$$$ISERR(sc) sc
        Set spec = OpenAPIV3
        $$$zlog("Conversion to version 3 done.")
    }

    If '$Isobject(spec) || ( $Extract(spec.openapi) '= "3" ) {
        Quit $$$ERROR($$$GeneralError, "Not an OpenAPI version 3 specification.")
    }

    If $Get(features("Parse"), 1) {
        ; Allows to simplify the structure for the code generation
        ; https://validator.swagger.io/
        $$$zlog("* Parse the definition with flatten=true to simplify the structure ... ")
        Set webValidator = ##class(dc.swaggervalidatorcli.WebSwaggerValidator).%New()
        Set webValidator.specification = spec
        Set queryParameters("flatten")="true", OpenAPIV3 = ""
        Set sc = webValidator.Parse(.queryParameters, .OpenAPIV3)
        Quit:$$$ISERR(sc) sc
        Set spec = OpenAPIV3
        $$$zlog("= Parse the definition with flatten=true done ...")
    }

    Return ..%CreateClientApplication(appName, spec, .features)
}

/// Return the swagger specification in a dynamic object <br/>
/// spec argument could be a stream, a dynamic object or an URL.<br/>
ClassMethod AbstractSpecLoader(spec, ByRef features As %Binary, ByRef sc As %Status = {$$$OK}) As %DynamicObject
{
    Set returnSpec = {}

    Try {
        If $Isobject(spec) {
            If spec.%IsA("%Stream.Object") {
                If ..isYAML(spec) { 

                    Set returnSpec = ..convertYAMLToJSON( spec, .sc)
                    If $$$ISERR(sc) $$$ThrowStatus(sc)
                
                } Else {
                    Set returnSpec = {}.%FromJSON(spec)
                }

            }
        } Else {
            If $ZCONVERT($Extract(spec, 1, 4), "l") = "http" {
                Set returnSpec = ..loadSpecFromUrl(spec,.features)
                If returnSpec.%IsDefined("servers")&&$IsObject(returnSpec.servers.%Get(0))&&($Extract(returnSpec.servers.%Get(0).url)="/") {
                    ; The contains only path like "/service/path", we add the complete URL https://server/service/path
                    Do ##class(%Net.URLParser).Decompose(spec, .components)
                    Set returnSpec.servers.%Get(0).url = $Get(components("scheme")) _ "://" 
                        _ $Select($Data(components("user"), user): user _ ":" _ $Get(components("password")) _"@",1:"") 
                        _ $Get(components("host"))
                        _ $Select($Data(components("port"), port): ":"_port,1:"") 
                        _ returnSpec.servers.%Get(0).url
                }
            } ElseIf ##class(%File).Exists(spec) {
                Set returnSpec = ..loadSpecFromFile(spec)
            } Else {
                $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Swagger specification not found %1.", spec)))
            }

        }
    } Catch(ex) {
        Set sc = ex.AsStatus()
        Set msg = $SYSTEM.Status.GetOneErrorText(sc)
        
        If msg [ "Parsing err" {
            Set sc = $$$ERROR($$$GeneralError, "Currently only JSON format is supported.")
        }
    }

    Return returnSpec
}

ClassMethod loadSpecFromFile(file As %String) As %DynamicObject
{
    Set stream = ##class(%Stream.FileCharacter).%New(), stream.Filename = file
    
    If ..isYAML(stream) { 
        
        Set spec = ..convertYAMLToJSON( stream, .sc)
        If $$$ISERR(sc) $$$ThrowStatus(sc)

    } Else {
        
        Set spec = {}.%FromJSON(.stream)

    }
    Return spec
}

ClassMethod loadSpecFromUrl(url As %String, ByRef features As %Binary) As %DynamicObject
{
    Set request = ##class(%Net.HttpRequest).%New()
    Set request.Server = $Piece($Piece(url,"/",3),":",1)
    Set request.Port = $Piece($Piece(url,"/",3),":",2)
    Set protocol = $Zcvt($Piece(url,":",1),"l")
    Set request.Https = (protocol="https")

    Set:$Get(features("Username"))'="" request.Username = features("Username")
    Set:$Get(features("Password"))'="" request.Password = features("Password")
    
    If request.Https {
        Set request.SSLConfiguration = "default"
    }

    $$$TOE(sc, request.Send("GET", $Piece(url,"/",4,*)))
    
    If request.HttpResponse.StatusCode '= 200 {
        $$$ThrowStatus($$$ERROR(5001, "Http status code : " _ request.HttpResponse.StatusCode ))
    }

    Set stream = request.HttpResponse.Data

    If ..isYAML(stream) { 

        Set spec = ..convertYAMLToJSON( stream, .sc)
        If $$$ISERR(sc) $$$ThrowStatus(sc)
    
    } Else {
        Set spec = {}.%FromJSON(stream)
    }

    Return spec
}

ClassMethod isYAML(stream As %Stream.Object) As %Boolean
{
    Do stream.Rewind()
    Set buffer = $zstrip(stream.Read(),"<W")
    Do stream.Rewind()
    Quit ($Extract(buffer) '= "{") && ((buffer [ "swagger: ")||buffer [ "openapi:")
}

ClassMethod convertYAMLToJSON(stream As %Stream.Object, Output sc As %Status) As %DynamicObject
{
    set lt = stream.Read()
	set:lt[$c(13,10) stream.LineTerminator = $c(13,10)
	do stream.Rewind()
    Quit ##class(YAML.Utils).StreamToJSON(stream, .sc)
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
