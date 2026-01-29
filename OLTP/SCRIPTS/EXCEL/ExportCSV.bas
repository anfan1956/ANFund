Attribute VB_Name = "Module1"
Option Explicit

Sub ExportListObjectToCsv(lo As ListObject, filePath As String)

    Dim f As Integer
    Dim r As Long, c As Long
    Dim line As String
    Dim arr As Variant
    Dim headers As Variant
    
    f = FreeFile
    
    Open filePath For Output As #f
    
    ' --- HEADERS ---
    headers = lo.HeaderRowRange.Value  ' 1×N array
    line = ""
    For c = 1 To UBound(headers, 2)
        line = line & EscapeCsv(headers(1, c))
        If c < UBound(headers, 2) Then line = line & ","
    Next
    Print #f, line
    
    ' --- DATA BODY ---
    arr = lo.DataBodyRange.Value  ' R×C array
    
    For r = 1 To UBound(arr, 1)
        line = ""
        For c = 1 To UBound(arr, 2)
            line = line & EscapeCsv(arr(r, c))
            If c < UBound(arr, 2) Then line = line & ","
        Next
        Print #f, line
    Next
    
    Close #f
End Sub
Private Function EscapeCsv(v) As String
    Dim s As String
    s = CStr(v)
    
    ' Escape double quotes
    If InStr(s, """") > 0 Then
        s = Replace(s, """", """""")
    End If
    
    ' Wrap in quotes if contains comma, quote, or newline
    If InStr(s, ",") > 0 Or InStr(s, """") > 0 Or InStr(s, vbLf) > 0 Then
        s = """" & s & """"
    End If
    
    EscapeCsv = s
End Function
Sub TestExport()
Dim ws As Worksheet, lo As ListObject
    Set ws = Worksheets("TABLES_DATA")
    Set lo = ws.ListObjects("DB_TABLES")
    
    Call ExportListObjectToCsv( _
            lo, _
            "D:\TradingSystems\OLTP\OLTP\EXCEL\DATABASE_OBJECTS_SCHEMAS.csv" _
         )
    
    MsgBox "Export complete"
End Sub

'''"C:\Temp\positions_export.csv" _

