#!/bin/bash
# Ejemplo de timbrado desde Bash

########### Notas ############
## Instalar el paquete curl ##
##############################

### Declaracion de Variables
USERID="UsuarioPruebasWS"
USERPASS="b9ec2afa3361a59af4b4d102d3f704eabdf097d4"
RFC="ESI920427886"
FILE_TMP="CadenaUTF8.txt"
FILE_TMP64="CadenaB64.txt"
URLTIMBRADO="https://t1demo.facturacionmoderna.com/timbrado/soap"
FILE_SOAPREQUEST="soap_request.xml"
GENERARTXT="false"
GENERARPDF="false"
GENERARCBB="false"
###

FILE=$(cat<<EOF
AX|101|2013-07-23T09:12:00|San Pedro Garza García|ingreso|Contado|Efectivo|Pago en una sola Exhibición|0009 - Banamex|100.00|0.00|116.00|MXN|0.00|20001000000200000192|\nESI920427886|COMERCIALIZADORA SA DE CV|PERSONA MORAL REGIMEN GENERAL DE LEY.\nCalzada del Valle|90|int-10|Col. Del Valle||San Pedro Garza Garcia.|Nuevo León|México|76888\nCalzada del Valle(Sucursal)|90|int-10|Col. Del Valle||San Pedro Garza Garcia.|Nuevo León|México|76888\nFPD020724PKA|FIRST DATA PROCUREMENTS MEXICO, S DE R.L. DE CV\nReforma|1000|Piso 2, Int-5|Centro||Alvaro Obregón|Distrito Federal|México|60000\nCONCEPTOS|2\n7899701|Pieza|Caja de Chocolates|1.00|50.00|50.00\n8789788|No aplica|Envio|1.00|50.00|50.00\nIMPUESTOS_TRASLADADOS|1\nIVA|16.00|16.00\nIMPUESTOS_RETENIDOS|1\nISR|200.00
EOF
)

echo $FILE > $FILE_TMP
B64STR=`base64 -w 0 -i $FILE_TMP`

SOAP_REQUEST=$( cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" xmlns:ns1="https://t1demo.facturacionmoderna.com/timbrado/soap" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:enc="http://www.w3.org/2003/05/soap-encoding"><env:Body><ns1:requestTimbrarCFDI env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"><param0 xsi:type="enc:Struct"><UserPass xsi:type="xsd:string">$USERPASS</UserPass><UserID xsi:type="xsd:string">$USERID</UserID><emisorRFC xsi:type="xsd:string">$RFC</emisorRFC><text2CFDI xsi:type="xsd:string">$B64STR</text2CFDI><generarTXT xsi:type="xsd:boolean">$GENERARTXT</generarTXT><generarPDF xsi:type="xsd:string">$GENERARPDF</generarPDF><generarCBB xsi:type="xsd:boolean">$GENERARCBB</generarCBB></param0></ns1:requestTimbrarCFDI></env:Body></env:Envelope>
EOF
)

echo $SOAP_REQUEST > $FILE_SOAPREQUEST
echo "solicitando Timbrado..."
echo "curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO"
soap_response=`curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO`

echo $soap_response
FILE_RESPONSE="response.xml"
echo $soap_response > $FILE_RESPONSE

xmlb64=`grep "<xml\sxsi:type=\"xsd:string\">.*<.xml>" $FILE_RESPONSE | sed -e "s/^.*<xml/<xml/" | cut -f2 -d">"| cut -f1 -d"<"`
cfdixml="cfdi.xml"
echo `echo $xmlb64 | base64 --decode > $cfdixml` 

echo "Timbrado generado con exito"
echo "El comprobante lo encuentra en el archivo $cfdixml"