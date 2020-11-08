
select ID, httpStatusCode, operation, operationStatusText, SUBSTRING(body,1)
from petshop.GenericResponse
order by id desc
