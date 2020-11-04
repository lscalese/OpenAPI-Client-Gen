Class dc.openapi.client.samples.InboundAdapter Extends Ens.InboundAdapter
{

Method OnInit() As %Status
{
    Return $$$OK
}

Method OnTask() As %Status
{
    Set sc = $$$OK
    
    Try {
        Set tStatement = ##class(%SQL.Statement).%New()
        
        $$$ThrowOnError(tStatement.%PrepareClassQuery("dc.openapi.client.samples.InputPet","qryNewRecord"))

        Set tResult = tStatement.%Execute()

        If tResult.%SQLCODE < 0 {
            $$$ThrowStatus($$$ERROR($$$SQLError, tResult.%SQLCODE, tResult.%Message))
        } 

        While tResult.%Next(.sc) {
            If $$$ISERR(sc) $$$ThrowStatus(sc)
            
            Set pet = ##class(dc.openapi.client.samples.InputPet).%OpenId(tResult.%Get("ID"),,.sc)
            If $$$ISERR(sc) $$$ThrowStatus(sc)

            $$$ThrowOnError(..BusinessHost.ProcessInput(pet))

            Set pet.state = "IP"
            $$$ThrowOnError(pet.%Save())
        }

    } Catch (ex) {
        Do ex.Log()
        Set sc = ex.AsStatus()
    }

    Return sc
}

}
