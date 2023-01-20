/// Business logic class defined by OpenAPI in dc.openapi.client.api.spec<br/>
/// Updated Nov 29, 2020 08:21:12
Class dc.openapi.client.api.impl Extends %REST.Impl [ ProcedureBlock ]
{

/// If ExposeServerExceptions is true, then details of internal errors will be exposed.
Parameter ExposeServerExceptions = 1;

/// Generate IRIS Interoperability client classes from OPEN API Specification.<br/>
/// The method arguments hold values for:<br/>
///     body, Open API Specification<br/>
///     appName, package name for your application.<br/>
///     simpleHttpClient, If set to 1, the generated code won't a production but a simple http client without Interoperability architecture.<br/>
/// WARNING: This method's signature has changed.
ClassMethod InteropClasses(body As %Stream.Object, appName As %String, simpleHttpClient As %String) As %Stream.Object
{
    

    If $Zconvert(body.Read(4), "l")="http" {
        Set spec = ##class(dc.openapi.client.Spec).loadSpecFromUrl("http"_body.Read())
    } Else {
        Set spec = {}.%FromJSON(.body)
    }

    Lock +^genClassApp(" "_appName):2
    If $Test {
        TSTART
        Try {
            
            If ##class(dc.openapi.client.Spec).packageExists(appName) {
                ; existing package security
                $$$ThrowStatus($$$ERROR(5001, $$$FormatText("Package name %1 exists, please choose an other package name", appName)))
            }

            Set features("compile") = $$$NO
            Set features("simpleHttpClientOnly") = ''+simpleHttpClient
            $$$TOE(sc, ##class(dc.openapi.client.Spec).%CreateClientApplication(appName, spec, .features))

            Do $SYSTEM.OBJ.ExportPackageToStream(appName, .xmlStream)
            
        } Catch (ex) {
            TROLLBACK
            Lock -^genClassApp(" "_appName)
            Throw ex
        }
        ; The has been exported to a stream.  We can delete all generated classes.
        ; Using TROLLBACK is a quick, dirty and efficient way...
        ; todo ... implement an other way to delete all generated classes defintion.
        TROLLBACK   
        Lock -^genClassApp(" "_appName)
    } Else {
        Set sc = $$$ERROR(5001, "Unable to acquire a lock "_appName)
        $$$ThrowStatus(sc)
    }
    
    Return xmlStream
}

/// OpenAPI spec 2.0 .
ClassMethod SwaggerSpec() As %DynamicObject
{
    Set tSc = ##class(%REST.API).GetApplication("dc.openapi.client.api",.swagger)
    Do swagger.info.%Remove("x-ISC_Namespace")
    Set swagger.basePath = "/swaggerclientgen/api"
    Set swagger.info.title = "Open API Client Gen"
    Set swagger.info.version = "0.0.1"
    Set swagger.host = %request.CgiEnvs("SERVER_NAME") _ ":" _ %request.CgiEnvs("SERVER_PORT") ;"localhost:52773"
    Do swagger.%ToJSON()
    Return swagger
}

}
