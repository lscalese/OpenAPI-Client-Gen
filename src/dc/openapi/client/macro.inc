ROUTINE dc.openapi.client.macro [Type=INC]

#def1arg zlog(%arg)                     Do ##class(dc.openapi.client.Utils).log(%arg)
#def1arg FindPropertyName(%arg)         ##class(Grongier.OpenApi.DefinitionV3).FindPropertyName(%arg)
#def1arg GetObjectScriptType(%arg)      ##class(Grongier.OpenApi.DefinitionV3).GetObjectScriptType(%arg)
 ;#define zNormalizeClassName(%arg)       $(%arg, "{}()-_$%/\", "")
#define zNormalizeClassName(%arg)       $zstrip(%arg, "*P")


#def1arg NormalizePropertyParamName(%arg)       %arg

#def1arg CodeNormalizeProperty(%arg)    $Select(%arg?1.A.AN:%arg,1:""""_%arg_"""")