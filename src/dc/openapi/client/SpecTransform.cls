Class dc.openapi.client.SpecTransform Extends %RegisteredObject
{

Property spec As %DynamicObject;

Property temp As %Binary [ MultiDimensional, Private ];

Parameter METHODLIST = "get put post delete options head patch";

Method %OnNew(spec As %DynamicObject) As %Status
{
    Set ..spec =  {}.%FromJSON(spec.%ToJSON()) 
    Quit $$$OK
}

Method transform(Output sc As %Status) As %DynamicObject
{
    Set sc = $$$OK

    Try {

        Set:'$isobject(..spec.definitions) ..spec.definitions = {} ; create an empty "definitions" if does not exists to avoid <invalid oref>
        
        $$$ThrowOnError(..initUniqueName())
        
        $$$ThrowOnError(..fixNestedObject()) ; move object definition from response and parameters to "definitions" or root "parameters".
        Set cnt = 0
        For  {
            
            $$$ThrowOnError(..flatDefinition(.move))    ; Keep only one level, move nested object to "definition" and add $ref for linked.
            
            Set cnt = $Increment(cnt) 
            Quit:move=0

            if cnt > 100 {
                
                ; prevent infinite loop ...
                $$$ThrowStatus($$$ERROR($$$GeneralError , "Doh! : I'm so sad '("))
            }
        }

        $$$ThrowOnError(..fixOperationId())     ; Generate if needed and translate operationId

        $$$ThrowOnError(..fixDefinitionId())    ; translate definition Id to prevent invalid method name.

        
    } Catch(ex) {
        Set sc = ex.AsStatus()
    }
    Quit:$$$ISERR(sc) ""

    Return ..spec
}

Method flatDefinition(ByRef move As %Integer) As %Status
{
  
    #dim sc As %Status = $$$OK
    #dim newDef As %DynamicObject = {}
    Set move = 0
    
    Set iter = ..spec.definitions.%GetIterator()

    while iter.%GetNext(.key, .def) {
        
        continue:'$ISOBJECT(def) ; for ignore __comment 
        
        continue:((def.type'="object")&&(def.type'="array"))||'$ISOBJECT(def.properties)
       
        Set iterP = def.properties.%GetIterator()
        
        while iterP.%GetNext(.keyP, .prop) {
            
            If (prop.type = "array") && ((prop.items.type = "object") || (prop.items.properties '= "")){
                ; set missing type
                Set prop.items.type = "object"
                ;
                
                Set name = $Select( prop.title = "": keyP _ "AnonymousItem", 1 : prop.title)
                Set name = ..getUniqueName(prop.items.title, prop.items)
                ;w !,"-i|",name, " ", $e(prop.items.%ToJSON(),1,80)
                Do ..spec.definitions.%Set(name , {}.%FromJSON(prop.items.%ToJSON()))
                Set prop.items = { "$ref" : ("#/definitions/" _ name) }

                Set move = move + 1
                
            } ElseIf (prop.type = "object") && (prop."$ref" = "")  && (prop.properties '= "") {
                
                Set name = $Select( prop.title = "": keyP _ "Anonymous", 1 : prop.title)
                Set name = ..getUniqueName( name, prop )
                ;w !,"-o|",name, " ", $e(prop.%ToJSON(),1,80)
                Do ..spec.definitions.%Set(name, {}.%FromJSON(prop.%ToJSON()))
                Do def.properties.%Remove(keyP)
                Do def.properties.%Set(keyP, {  "$ref" : ("#/definitions/" _ name) })
                
                
                Set move = move + 1
            } 

        }
    }
    
    Return sc
}

Method getUniqueName(name As %String, compare As %DynamicObject = "") As %String
{
    Set:name="" name = "AnonymousDef"
    Set uniqueName = name
    
    
    ; desperate attempt to reduce the number of generate class if we don't have class identifier such as #/definitions/classname

    If $Isobject( compare ) {
        Set existingObject = ..spec.definitions.%Get( name )

        Set compareString = compare.%ToJSON()

        If $isobject(existingObject) {
            ;w !,1,"|exists|",(existingObject.%ToJSON()=compareString),"|",name
            Quit:existingObject.%ToJSON()=compareString name
        }

        Set key = 1 ; ignore first
        For i=2:1:+$g(..temp("uniqueDef", " "_name)) {
            
            Set existingObject = ..spec.definitions.%Get( name _ i )
            continue:'$Isobject(existingObject)
            
            ;w !,2,"|exists|",(existingObject.%ToJSON()=compareString),"|",name
            Return:existingObject.%ToJSON()=compareString name _ i
            
        }

    }

    If $Data(..temp("uniqueDef", " "_name)) {
        
        Set n = $Increment(..temp("uniqueDef", " "_name))
        Set ..temp("uniqueDef", " "_name) = n

        Set uniqueName = uniqueName _ n 
        
    } Else { 
        Set ..temp("uniqueDef", " "_name) = 1
    }

    Return uniqueName
}

Method initUniqueName() As %Status
{
    #dim sc As %Status = $$$OK
    
    Set iter = ..spec.definitions.%GetIterator()

    while iter.%GetNext(.key, .def) {
        Set ..temp("uniqueDef", " " _ key) = 1
    }

    Return sc
}

Method fixNestedObject() As %Status
{
    #dim sc As %Status = $$$OK
    ;#dim spec As %Library.DynamicObject = ..spec
    #dim iter As %Iterator.AbstractIterator = ..spec.paths.%GetIterator()
    #dim serviceLocation As %String
    #dim serviceDefinition As %Library.DynamicObject
    #dim method As %String

    #define zMoveCondition(%obj) ( %obj.schema.type = "object" && (%obj.schema."$ref" = "") || $ISOBJECT(%obj.schema.allOf) )
    #define zMoveArrCondition(%obj) ( %obj.schema.type = "array" && $Isobject(%obj.schema.items.allOf) )

    While iter.%GetNext(.serviceLocation , .value ) {

       
       Set methodIter = value.%GetIterator()

        While methodIter.%GetNext(.method , .serviceDefinition ) {
        
           continue:..#METHODLIST'[method


            ; firstable move parameters to the method -> operation level

            If $Isobject(value.parameters) {

                
                Set iterP = value.parameters.%GetIterator()
                While (iterP.%GetNext(.keyTabParam, .valueParam)) {
                    If '..paramExists(valueParam, serviceDefinition.parameters ) {
                        Do serviceDefinition.parameters.%Push({}.%FromJSON(valueParam.%ToJSON()))
                    }
                }
            }

            ;


           ; move nested object definition for responses
           If $ISOBJECT(serviceDefinition.responses) {
                
                Set iterResp = serviceDefinition.responses.%GetIterator()

                While iterResp.%GetNext(.httpStatusCode , .codeObj ) {
                    
                    If $$$zMoveCondition(codeObj) {
                        
                        Do mvToDef( httpStatusCode, codeObj )

                    } ElseIf $$$zMoveArrCondition(codeObj) {

                        Do mvArray( httpStatusCode, codeObj )

                    }

                    ; Fix an issue when a yaml has been convert to json
                    ; ex key 200 quoted --> { "\"200\"": { ... }}

                    If httpStatusCode [ """" {
                        Do serviceDefinition.responses.%Set( $Translate(httpStatusCode, """"), codeObj )
                        Do serviceDefinition.responses.%Remove( httpStatusCode )
                    }
                    
                }
            }

            ; move nested object definition for parameters


            If $ISOBJECT(serviceDefinition.parameters) {
                
                Set iterResp = serviceDefinition.parameters.%GetIterator()

                While iterResp.%GetNext(.keyParameter , .paramDef ) {
                    
                    continue:'$ISOBJECT(paramDef) ; To ignore __comment 

                    If $$$zMoveCondition(paramDef) {
                        
                        Do mvToDef( keyParameter, paramDef )

                    } ElseIf $$$zMoveArrCondition(paramDef) {

                        Do mvArray( keyParameter, paramDef )

                    }
                    
                }
            }
            
        }


    }
 
    Quit:'$Isobject( ..spec.parameters ) sc

    ; move parameters structure definition to #/definitions/

    Set iter = ..spec.parameters.%GetIterator()

    While iter.%GetNext( .keyParam, .param) {
        
        Continue:'$ISOBJECT(param)

        
        If $$$zMoveCondition(param) {

            Do mvToDef(keyParam, param)

        } ElseIf $$$zMoveArrCondition(param) {

            Do mvArray(keyParam, param)

        }
    }

    Return sc
 
mvToDef(key, obj)
    Quit:'$Isobject(obj.schema)
    Set name = $Select( obj.schema.title'="" : obj.schema.title, obj.name'="": obj.name, $Isvalidnum(key): "R" _ key, 1: key )
    Set name = ..getUniqueName( name , obj.schema )
    Do ..spec.definitions.%Set(name, {}.%FromJSON(obj.schema.%ToJSON()))
    Set obj.schema = { "$ref" : ("#/definitions/" _ name) }
    Quit

mvArray(key, obj)
    Quit:'$Isobject(obj.schema)
    ;Set name = ..getUniqueName( obj.schema.title, obj.schema.items )
    ;Set name = $Select( obj.schema.title'="" : obj.schema.title, obj.name'="": obj.name, 1: key )
    Set name = $Select( obj.schema.title'="" : obj.schema.title, obj.name'="": obj.name, $Isvalidnum(key): "R" _ key, 1: key )
    Set name = ..getUniqueName( name, obj.schema.items )
    Do ..spec.definitions.%Set(name, {}.%FromJSON(obj.schema.items.%ToJSON()))
    Set obj.schema.items = { "$ref" : ("#/definitions/" _ name) }
    Quit
}

Method fixOperationId() As %Status
{
    #dim sc As %Status = $$$OK
    #dim spec As %Library.DynamicObject = ..spec
    #dim iter As %Iterator.AbstractIterator = spec.paths.%GetIterator()
    #dim serviceLocation As %String
    #dim serviceDefinition As %Library.DynamicObject
    #dim method As %String

    
    While iter.%GetNext(.serviceLocation , .value ) {
        
        
        
        Set methodIter = value.%GetIterator()

        While methodIter.%GetNext(.method , .serviceDefinition ) {

            continue:..#METHODLIST'[method

            ; issue #15 https://github.com/lscalese/OpenAPI-Client-Gen/issues/15
            If serviceDefinition.operationId = "" {

                Set operationIdentifier = ..translateOperationId(..generateOperationId(method, serviceLocation))    
                Set serviceDefinition.operationId = operationIdentifier

            } Else {
                ; clean attempt for operationId contain /, path variable, ...
                Set serviceDefinition.operationId = $Select($Get(%zCleanSID, 1): ..cleanOperationId(serviceDefinition.operationId), 1: ..translateOperationId(serviceDefinition.operationId))
                    
            }

            #define kOpId " " _ serviceDefinition.operationId

            If '$Data(usedIdentifier($$$kOpId)) {
                Set usedIdentifier($$$kOpId) = 1
            } Else {
                Set usedIdentifier($$$kOpId) = usedIdentifier($$$kOpId) +1 
                Set serviceDefinition.operationId = serviceDefinition.operationId _ usedIdentifier($$$kOpId)
            }

            If $ISOBJECT(serviceDefinition.responses) {
                Set iterResp = serviceDefinition.responses.%GetIterator()
                While iterResp.%GetNext(.httpStatusCode , .codeObj ) {
                    Set:codeObj.schema."$ref"'="" codeObj.schema."$ref" = ..translateName(codeObj.schema."$ref")
                    Set:codeObj.schema.items."$ref"'="" codeObj.schema.items."$ref" = ..translateName(codeObj.schema.items."$ref")
                }
            }

            If $ISOBJECT(serviceDefinition.parameters) {
                Set iterParams = serviceDefinition.parameters.%GetIterator()
                While iterParams.%GetNext(.paramsKey , .param ) {
                    Set:param.schema."$ref"'="" param.schema."$ref" = ..translateName(param.schema."$ref")
                    Set:param.schema.items."$ref"'="" param.schema.items."$ref" = ..translateName(param.schema.items."$ref")
                }
            }

                        
        }
    }

    Return sc
}

Method fixDefinitionId() As %Status
{
    #dim sc As %Status = $$$OK

    #dim spec As %DynamicObject = ..spec

    Set newDef = {}, defKey = ""
    
    Set iter = spec.definitions.%GetIterator()

    While iter.%GetNext(.defKey , .def ) {
                
        If '$Isobject(spec.definitions.%Get(defKey)) {
            Do spec.definitions.%Remove(defKey)
            Continue
        }

        Set copyDef = {}.%FromJSON(def.%ToJSON())
        Do spec.definitions.%Remove(defKey)

        If $ISOBJECT(copyDef.properties) {
            Set iterProp = copyDef.properties.%GetIterator()

            While iterProp.%GetNext(.propKey , .propDef ) {
                Set:propDef."$ref"'="" propDef."$ref" = ..translateName(propDef."$ref")
                Set:propDef.items."$ref"'="" propDef.items."$ref" = ..translateName(propDef.items."$ref")
            }
        }

        Set newDefKey = ..translateName(defKey)
        Do newDef.%Set(..translateName(defKey), copyDef)
    }

    Set spec.definitions = newDef

    Return $$$OK
}

ClassMethod translateOperationId(name As %String) As %IO.StringStream
{
    Return $Translate(name, "_/{}-.", "")
}

ClassMethod translateName(name As %String) As %IO.StringStream
{
    Return $Translate(name, "_ ", "")
}

ClassMethod cleanOperationId(originalId As %String) As %String
{
   
    Set m=##class(%Regex.Matcher).%New("\{.*?\}", originalId)
    Set id = m.ReplaceAll("")
    Set list = $LFS(id , "/"), ptr = 0, id = ""
    While $ListNext(list, ptr, item) {
        
        Set $Extract(item,1) = $Zcvt($Extract(item,1), "U")
        Set id = id _ item 
        
    }
    
    Return ..translateOperationId(id)
}

ClassMethod generateOperationId(method As %String, path As %String) As %String
{
    Set list = $LFS(path, "/"), ptr = 0, id = ""
    
    While $ListNext(list, ptr, item) {
        Set:$Extract(item, 1)'="{" id = id _ item  ; exclude path parameter
    }
    
    Return method _ id
}

ClassMethod paramExists(source As %DynamicObject, target As %DynamicObject) As %Boolean
{
    Quit:'$Isobject(target) 0

    Set exists = $$$NO

    Set iterResp = target.%GetIterator()

    While iterResp.%GetNext(.keyParameter , .paramDef ) {
        
        if (paramDef.in = source.in) && (paramDef.name = source.name) {
            Return 1
        }

    }

    Return exists
}

}
