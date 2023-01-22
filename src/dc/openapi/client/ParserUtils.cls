Include (dc.openapi.client.macro, dc.openapi.common.macro)

Class dc.openapi.client.ParserUtils
{

ClassMethod MergeParametersArray(from As %DynamicArray, to As %DynamicArray) As %DynamicArray
{
    #dim target As %DynamicArray = {}.%FromJSON(from.%ToJSON())

    Set names = ""
    Set iter = from.%GetIterator()
    While iter.%GetNext(.key, .parameter) {
        Set names(" "_parameter.name)=key
    }

    Set iter = to.%GetIterator()
    While iter.%GetNext(.key, .parameter) {
        Set:$Data(names(" "_parameter.name), key) del(key) = ""
        Do target.%Push(parameter)
    }

    Set key = ""
    For  {
        Set key = $Order(del(key), -1, pos)
        Quit:key=""
        Do target.%Remove(pos)
    }

    Quit target
}

ClassMethod GetObjectByRef(specification As %DynamicObject, reference As %String, Output name As %String) As %DynamicObject
{
    /// ex reference : "#/components/schemas/model"

    Set tmpObjRef =  specification, name = $Piece(reference, "/", *)

    For i=2:1:$Length(reference, "/") {
        Set tmpObjRef = tmpObjRef.%Get($Piece(reference, "/", i))
        Quit:tmpObjRef=""
    }

    If '$ISOBJECT(tmpObjRef) $$$zlog($Char(9) _ "! Reference : """ _ reference _ """ not found.")

    Quit tmpObjRef
}

/// Common parsing for specifications flatten = true.
/// These specification haven't nested object.
ClassMethod CommonSchemaProcessForFlatteSpec(classDef As %Dictionary.ClassDefinition, propDef As %Dictionary.PropertyDefinition, schema As %DynamicObject, package As %String, specification) As %Status
{
    Set sc = $$$OK

    If schema.%IsDefined("$ref") {
        Set schema = ..GetObjectByRef(specification, schema."$ref", .refName)
        Quit:'$IsObject(schema) sc

        If schema.type = "object" {
            Set propDef.Type = package _ "." _ $$$zNormalizeClassName(refName)
            Do classDef.Properties.Insert(propDef)
            Quit sc
        }
    }

    If schema.type = "array" {

        Set propDef.Collection = "list"

        If schema.items."$ref" '="" {
            Set refObject = ..GetObjectByRef(specification, schema.items."$ref", .refName)
            Quit:'$IsObject(refObject) sc
            
            Set propDef.Type = $Select(refObject.type="object": package _ "." _ $$$zNormalizeClassName(refName), 1: $$$GetObjectScriptType(refObject.type,refObject.format))
            
        } Else {

            Set propDef.Type = $$$GetObjectScriptType(schema.items.type,schema.items.format)
        
        }
    
    } Else {
        w !,schema.type,schema.format
        Set propDef.Type = $$$GetObjectScriptType(schema.type,schema.format)
    }

    Do classDef.Properties.Insert(propDef)

    Quit sc
}

}
