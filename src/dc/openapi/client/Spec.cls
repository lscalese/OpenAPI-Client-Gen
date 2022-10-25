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
ClassMethod generateApp(appName As %String, spec, features As %Binary) As %Status
{
    Set sc = $$$OK
    Try {
        If $Isobject(spec) {
            If spec.%IsA("%Stream.Object") {

                If ..isYAML(spec) { 

                    Set spec = ..convertYAMLToJSON( spec, .sc)
                    If $$$ISERR(sc) $$$ThrowStatus(sc)
                
                } Else {
                    Set spec = {}.%FromJSON(spec)
                }

            }
        } Else {
            If $ZCONVERT($Extract(spec, 1, 4), "l") = "http" {
                Set spec = ..loadSpecFromUrl(spec,.features)
            } ElseIf ##class(%File).Exists(spec) {
                Set spec = ..loadSpecFromFile(spec)
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
    
    Quit:$$$ISERR(sc) sc

    If '$Isobject(spec) || (spec.swagger '= "2.0" ) {
        Quit $$$ERROR($$$GeneralError, "Not a Swagger 2.0 file.")
    }

   

    Return ..%CreateClientApplication(appName, spec, .features)
}

ClassMethod loadSpecFromFile(file As %String) As %DynamicObject
{
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set stream.Filename = file
    
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
    Quit ($Extract(buffer) '= "{") && (buffer [ "swagger: ")
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
   
    TStart 
    Try {
        
        Set specClass = applicationName _ ".model.spec"

        Set cDef=##class(%Dictionary.ClassDefinition).%OpenId(specClass,4,.sc)
        
        If $Isobject(cDef) {
            Do ..%RemoveXDataBlock(cDef,..#XDataName)
            Set newApplication = $$$NO
        } Else {
            Set cDef=##class(%Dictionary.ClassDefinition).%New(specClass)
            Set newApplication = $$$YES
        }

        ; $$$TOE(sc, ..generateSimpleClient()) ; must be refactor
        ; security to avoid overwrite an existing package on the server ...
        If newApplication && ##class(dc.openapi.client.Generator).packageExists(applicationName)  { 
            Set sc = $$$ERROR(5001, "Overwritting code protection.  This package already exist on the server, please choose an other appName "_applicationName)
            $$$ThrowStatus(sc)
        }

        Set cDef.Super = "%RegisteredObject"
        Set cDef.ProcedureBlock = $$$YES

        Set xData=##class(%Dictionary.XDataDefinition).%New()
        Set xData.Name=..#XDataName
        Set xData.MimeType="application/json"

        Set formatter=##class(%JSON.Formatter).%New()
        
        ; work around for an open problem with the model generation library
        ; https://github.com/grongierisc/objectscript-openapi-definition/issues/4
        Kill ^CacheTemplsc
        Set ^CacheTemplsc(0) = swagger.%ToJSON()
        Set transformer = ##class(dc.openapi.client.SpecTransform).%New(swagger)
        Set swagger = transformer.transform(.sc)
        
        If $$$ISERR(sc) $$$ThrowStatus(sc)

        ; keep the last transformed swagger (debug purpose)
        Set ^CacheTemplsc(1) = swagger.%ToJSON()
        Kill transformer

        $$$ThrowOnError(formatter.FormatToString(swagger, .swaggerString))
        $$$ThrowOnError(xData.Data.Write(swaggerString))
        $$$ThrowOnError(cDef.XDatas.Insert(xData))
        $$$ThrowOnError(cDef.%Save())
        $$$ThrowOnError($system.OBJ.Compile(specClass,"ck-d"))
        
        Set generator = ##class(dc.openapi.client.Generator).%New(swagger, applicationName, $Get(features("compile"),$$$YES), $Get(features("simpleHttpClientOnly"),$$$NO))
        Set sc = generator.generate()

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

ClassMethod %RemoveXDataBlock(cDef, blockName)
{
 	Set key = cDef.XDatas.FindObjectId(cDef.Name_"||"_blockName)
 	If (key'="") {
 		Set oid = cDef.XDatas.RemoveAt(key)
	}
}

}
