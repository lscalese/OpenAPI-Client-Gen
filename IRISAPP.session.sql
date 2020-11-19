
select ID, httpStatusCode, operation, operationStatusText, SUBSTRING(body,1)
from petshop_msg.GenericResponse
order by id desc
