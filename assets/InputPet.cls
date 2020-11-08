Class dc.openapi.client.samples.InputPet Extends %Persistent
{

Property petName As %String;

Property categoryName As %String;

Property categoryId As %String;

/// N : New record<br/>
/// IP : In Progress<br/>
/// D : Done<br/>
Property state As %String [ InitialExpression = "N" ];

Index stateI On state;

Query qryNewRecord() As %SQLQuery(CONTAINID = 1) [ SqlProc ]
{
    SELECT ID, petName, categoryName, categoryId 
    FROM dc_openapi_client_samples.InputPet
    WHERE state = 'N'
}

ClassMethod markAs(id As %Integer, state As %String) As %Status [ Private ]
{
    Set sc = $$$OK

    &SQL(UPDATE dc_openapi_client_samples.InputPet SET state = :state WHERE ID = :id)
    
    If SQLCODE < 0 {
        Set sc = $$$ERROR($$$SQLError, SQLCODE)
    }

    Return sc
}

ClassMethod markAsDone(id As %Integer) As %Status
{
    Return ..markAs(id, "D")
}

ClassMethod markAsInProgress(id As %Integer) As %Status
{
    Return ..markAs(id, "IP")
}

Storage Default
{
<Data name="InputPetDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>petName</Value>
</Value>
<Value name="3">
<Value>categoryName</Value>
</Value>
<Value name="4">
<Value>categoryId</Value>
</Value>
<Value name="5">
<Value>state</Value>
</Value>
</Data>
<DataLocation>^dc.openapi.client66E9.InputPetD</DataLocation>
<DefaultData>InputPetDefaultData</DefaultData>
<IdLocation>^dc.openapi.client66E9.InputPetD</IdLocation>
<IndexLocation>^dc.openapi.client66E9.InputPetI</IndexLocation>
<StreamLocation>^dc.openapi.client66E9.InputPetS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
