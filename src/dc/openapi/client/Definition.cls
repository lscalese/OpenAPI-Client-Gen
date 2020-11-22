/// %REST.Definition generates definition classes based on a OpenAPI specification class.
Class dc.openapi.client.Definition Extends %RegisteredObject
{

/// To used class definition generator
/// Open a terminal and lunch this classmethod as this :
/// zw ##class(Grongier.OpenApi.Definition).Process("PetShop.spec")
/// Result is a new package in eg : PetShop.Definition with all the definition class ready to use.
ClassMethod Process(specClass As %String = "PetStore.spec") As %Status
{
    // Get API Definition
    Do ##class(%REST.RESTSpec).GetSpecificationXData(specClass,,.txdata)
    Set openapispec = ##class(%DynamicObject).%FromJSON(txdata.Data)
    Set definitions = openapispec.definitions
	Set %zdefinitions = openapispec.definitions
	// Get package definiton
	set package = $p(specClass,".",1,*-1)
	set definitionPackage = package_".Definition"

	// Iter throw api definitions
    Set iterDefinitions = definitions.%GetIterator()
    while iterDefinitions.%GetNext(.key , .value ) {
        ;w !,"key|",key,"|",value.type,"|",definitionPackage_"."_key
        s:((value.type = "object")||$isobject(value.allOf)) a=..GenerateClass(definitionPackage_"."_key,value)
		;w:((value.type = "object")||$isobject(value.allOf)) "|",$System.Status.GetOneErrorText(a)
    }
    
	Quit $System.OBJ.CompilePackage(definitionPackage)
}

ClassMethod GenerateClass(name As %String, object As %DynamicObject) As %Status
{
	#dim classDef as %Dictionary.ClassDefinition
    Do ..CreateClassDef(name,.classDef)

	Set objectProperties = object
	// Add super class
	Set parent="%JSON.Adaptor,%RegisteredObject"
	If $Isobject(object.allOf) {
		Set:$isobject(object.allOf.%Get(0)) parent=parent _ "," _$Replace(object.allOf.%Get(0)."$ref","#/definitions/", "")
		Set:$isobject(object.allOf.%Get(1)) objectProperties = object.allOf.%Get(1)
	} 
	// Fix issue for ProcedureBlock
	Set classDef.Super = parent
	Set classDef.ProcedureBlock = 1

	
	
    // For each property

	If $isobject( objectProperties.properties ) {
		Set iterProperty = objectProperties.properties.%GetIterator()
		Set listRequired = objectProperties.required
		Set:(listRequired="") listRequired = ##class(%DynamicArray).%New()
		while iterProperty.%GetNext( .key , .value ) {
			
			Do ..CreateProperty(classDef,key,value,listRequired)   
			
		}
	}

	
    Quit classDef.%Save()
}

/// Create a class definition object
ClassMethod CreateClassDef(className As %String, Output classDef As %Dictionary.ClassDefinition) As %Status [ Internal, Private ]
{
	Set classDef=""
	If className="" Quit $$$OK
	
    #; Delete any pre-existing definition
    If $$$defClassDefined(className) {
        Set sc=$$Delete^%apiOBJ(className,"-d")
        If $$$ISERR(sc) Quit sc
    }

	#; Create a new class definition
	Kill %objlasterror
	Set classDef=##class(%Dictionary.ClassDefinition).%New(className)
	If '$isobject(classDef) {
		Quit $get(%objlasterror,$$$ERROR($$$FailedToCreateClass,className))
	}
	
	Quit $$$OK
}

/// Create a property
ClassMethod CreateProperty(classDef As %Dictionary.ClassDefinition, name As %String, value As %DynamicObject, listRequired As %DynamicArray, desc As %String, allowOverride As %Boolean = 1) As %Status [ Internal ]
{
 	Set sc=$$$OK
	Set className=classDef.Name
	
	Set paramPos=""
	// Look for existing property
	For i=1:1:classDef.Properties.Count() {
		If classDef.Properties.GetAt(i).Name=name {
			Set paramPos=i
			Quit
		}
	}

	// If override not allowed and property already present, then just exit. 	
	If 'allowOverride,paramPos'="" Quit $$$OK

 	// Create a new property
	Set propName=className_":"_name
	Kill %objlasterror
	Set propDef=##class(%Dictionary.PropertyDefinition).%New(propName)
	If propDef="" {
		Quit $get(%objlasterror,$$$ERROR($$$FailedToCreateClass,propName) )
 	}

	// Fill in the type, value and description
	Do ..GetObjectScriptType(value,.propDef)
	Set propDef.Description=$get(desc)

	// Set property as required
	Set N=listRequired.%Size()
	For i=0:1:N-1 {
    	Set:(name=listRequired.%Get(i)) propDef.Required = 1
	}

	// Set Min and Max if defined
	do:(value.minimum'="") propDef.Parameters.SetAt(value.minimum,"MINVAL")
	do:(value.maximum'="") propDef.Parameters.SetAt(value.maximum,"MAXVAL")
	do:(value.minLength'="") propDef.Parameters.SetAt(value.minLength,"MINLEN")
	do:(value.maxLength'="") propDef.Parameters.SetAt(value.maxLength,"MAXLEN")

	// Set enum to valuelist
	if value.enum '= "" {
		#dim enums as %Library.DynamicArray
		set enums = value.enum
		if enums.%IsA("%DynamicArray") {
			Set iter = enums.%GetIterator()
			Set valueList = ""
			While iter.%GetNext(.key , .enum ) {
				set isDyna = 0
				Try {
					set isDyna = enum.%IsA("%Library.DynamicObject")
				}
				Catch {
					//Do nothing
				}
				if 'isDyna {
					// OpenAPI 2.0
					Set valueList = valueList _","_ enum
				}
				else {
					// OpenAPI 3.0
					// Get first value of object
					set iterEnum = enum.%GetIterator()
					do iterEnum.%GetNext(.keyEnum , .enumValue )
					Set valueList = valueList _","_ enumValue
				}
				
			}
		}
		do propDef.Parameters.SetAt(valueList,"VALUELIST") 
	}

	// Insert into the class definition
	If paramPos="" {
		Do classDef.Properties.Insert(propDef)
	} Else {
		Do classDef.Properties.SetAt(propDef,paramPos)
	}

	Quit $$$OK
}

/// Get the ObjectScript type for a property.
ClassMethod GetObjectScriptType(property As %DynamicObject, propDef) As %Status [ Internal ]
{
	#define SimpleType(%property) $case(%property.type,"string":"%String","number":"%Float","integer":"%Integer","boolean":"%Boolean","":%property."$ref",:"%VarString")

	#define GetSimpleCOSType(%type) $case(%type,"string":"%String","number":"%Float","integer":"%Integer","boolean":"%Boolean",:"%VarString")
	
	Set type=property.type
	
	If type="array" {
		Set propDef.Collection="list"
		Set propDef.Type = $Replace($$$SimpleType(property.items),"#/definitions/","")
		
		Set tmpType = $$$SimpleType(property.items)

		; check if the target is a object or simple type
		If tmpType [ "#/definitions/" {
			Set tmpType = $Replace(tmpType,"#/definitions/",""), targetType = %zdefinitions.%Get(tmpType).type
			If targetType '= "object" {
				Set tmpType = $$$GetSimpleCOSType(targetType)
			}
		}

		Set propDef.Type = tmpType

	} ElseIf type="file" {
		Set propDef.Type="%Stream.Object"

	} Else {
		;Set propDef.Type=$Replace($$$SimpleType(property),"#/definitions/","")
		Set tmpType = $$$SimpleType(property)
		If tmpType [ "#/definitions/" {
			; check if the target is a object or simple type
			Set tmpType = $Replace(tmpType,"#/definitions/",""), targetType = %zdefinitions.%Get(tmpType).type
			If targetType '= "object" {
				Set tmpType = $$$GetSimpleCOSType(targetType)
			}
		}
		Set propDef.Type = tmpType
	}
	
	
	
	
	Quit $$$OK
}

}
