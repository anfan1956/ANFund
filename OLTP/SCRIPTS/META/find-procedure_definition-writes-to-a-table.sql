-- Find stored procedures that write to trd.positionState
SELECT 
    OBJECT_NAME(object_id) AS procedure_name,
    OBJECT_DEFINITION(object_id) AS procedure_definition
FROM sys.procedures 
WHERE OBJECT_DEFINITION(object_id) LIKE '%trd.positionState%'
   OR OBJECT_DEFINITION(object_id) LIKE '%positionState%'
ORDER BY procedure_name;

-- Also check for triggers
SELECT 
    OBJECT_NAME(parent_id) AS parent_object,
    name AS trigger_name,
    OBJECT_DEFINITION(object_id) AS trigger_definition
FROM sys.triggers 
WHERE OBJECT_DEFINITION(object_id) LIKE '%trd.positionState%'
   OR OBJECT_DEFINITION(object_id) LIKE '%positionState%';