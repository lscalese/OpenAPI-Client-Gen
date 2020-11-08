Class dc.openapi.client.samples.PetShop
{

ClassMethod generatePetShopClient() As %Status
{
    Write !,"Generate application dc.openapi.client.petshop..."

    Set sc = ##class(dc.openapi.client.Spec).generateApp("petshop", "https://petstore.swagger.io:443/v2/swagger.json")
    
    Write "Status : ", $SYSTEM.Status.GetOneErrorText(sc)

    Return sc
}

}
