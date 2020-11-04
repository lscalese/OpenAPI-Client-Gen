/// Dispatch class defined by RESTSpec in dc.openapi.client.api.spec
Class dc.openapi.client.api.disp Extends %CSP.REST [ GeneratedBy = dc.openapi.client.api.spec.cls, ProcedureBlock ]
{

/// The class containing the RESTSpec which generated this class
Parameter SpecificationClass = "dc.openapi.client.api.spec";

/// Ignore any writes done directly by the REST method.
Parameter IgnoreWrites = 1;

/// By default convert the input stream to Unicode
Parameter CONVERTINPUTSTREAM = 1;

/// The default response charset is utf-8
Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Generate IRIS Interoperability client classes from OPEN API Specification. -->
  <Route Url="/interopclasses/:appName" Method="post" Call="InteropClasses" />
  <!-- OpenAPI spec 2.0 -->
  <Route Url="/_spec" Method="get" Call="SwaggerSpec" />
</Routes>
}

/// Generate IRIS Interoperability client classes from OPEN API Specification.
ClassMethod InteropClasses(pappName As %String) As %Status
{
    Try {
        If $case(%request.ContentType,"application/json":0,:1) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP415UNSUPPORTEDMEDIATYPE,$$$ERROR($$$RESTContentType,%request.ContentType)) Quit
        Do ##class(%REST.Impl).%SetContentType("application/xml")
        If '##class(%REST.Impl).%CheckAccepts("application/xml") Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts)) Quit
        If '$isobject(%request.Content) Do ##class(%REST.Impl).%ReportRESTError(..#HTTP400BADREQUEST,$$$ERROR($$$RESTRequired,"body")) Quit
        Set pbody=%request.Content
        Set response=##class(dc.openapi.client.api.impl).InteropClasses(pbody,pappName)
        Do ##class(dc.openapi.client.api.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("dc.openapi.client.api.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

/// OpenAPI spec 2.0
ClassMethod SwaggerSpec() As %Status
{
    s ^lsc("sw")=$zdt($h,3,1)
    Try {
        Do ##class(%REST.Impl).%SetContentType("application/json")
        If '##class(%REST.Impl).%CheckAccepts("application/json") Do ##class(%REST.Impl).%ReportRESTError(..#HTTP406NOTACCEPTABLE,$$$ERROR($$$RESTBadAccepts)) Quit
        Set response=##class(dc.openapi.client.api.impl).SwaggerSpec()
        Do ##class(dc.openapi.client.api.impl).%WriteResponse(response)
    } Catch (ex) {
        Do ##class(%REST.Impl).%ReportRESTError(..#HTTP500INTERNALSERVERERROR,ex.AsStatus(),$parameter("dc.openapi.client.api.impl","ExposeServerExceptions"))
    }
    Quit $$$OK
}

}
