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
GENERARPDF="true"
GENERARCBB="false"
FILE_RESPONSE="response.xml"
cfdixml="cfdi.xml"
cfdipdf="cfdi.pdf"
###

FILE=$(cat<<EOF
AA|21|2013-07-23T09:12:00|Nuevo León, México|ingreso|Contado|Cheque|Pago en una sola Exhibición|No identificado|1498.00|0.00|1737.68|MXN|0.00|20001000000200000278|\nTUMG620310R95|FACTURACION MODERNA SA DE CV|PERSONA MORAL REGIMEN GENERAL DE LEY.\nRIO GUADALQUIVIR|238||ORIENTE DEL VALLE||San Pedro Garza Garcia|Nuevo León|México|66220\n||||||||\nXAXX010101000|PUBLICO EN GENERAL\nCERRADA DE AZUCENAS|109||REFORMA||OAXACA DE JUAREZ|OAXACA|México|68050\nCONCEPTOS|2\n|PIEZA|CAJA DE HOJAS BLANCAS TAMAÑO CARTA|3|450.00|1350.00\n|PIEZA|RECOPILADOR PASTA DURA 3 ARILLOS|8|18.50|148.00\nIMPUESTOS_TRASLADADOS|1\nIVA|16.00|239.68
EOF
)

echo $FILE > $FILE_TMP
B64STR=`base64 -i $FILE_TMP`

SOAP_REQUEST=$( cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" xmlns:ns1="https://t1demo.facturacionmoderna.com/timbrado/soap" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:enc="http://www.w3.org/2003/05/soap-encoding"><env:Body><ns1:requestTimbrarCFDI env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"><param0 xsi:type="enc:Struct"><UserPass xsi:type="xsd:string">$USERPASS</UserPass><UserID xsi:type="xsd:string">$USERID</UserID><emisorRFC xsi:type="xsd:string">$RFC</emisorRFC><text2CFDI xsi:type="xsd:string">$B64STR</text2CFDI><generarTXT xsi:type="xsd:boolean">$GENERARTXT</generarTXT><generarPDF xsi:type="xsd:string">$GENERARPDF</generarPDF><generarCBB xsi:type="xsd:boolean">$GENERARCBB</generarCBB></param0></ns1:requestTimbrarCFDI></env:Body></env:Envelope>
EOF
)

echo $SOAP_REQUEST > $FILE_SOAPREQUEST
echo "solicitando Timbrado..."
soap_response=`curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO`

echo $soap_response > $FILE_RESPONSE

## Verificar que no haya ocurrido un error
code=""
code=`grep "<env:Body>.*<.env:Body>" $FILE_RESPONSE | sed -e "s/^.*<env:Value/<env:Value/" | cut -f2 -d">" | cut -f1 -d"<"`
message=`grep "<env:Body>.*<.env:Body>" $FILE_RESPONSE | sed -e "s/^.*<env:Text/<env:Text/" | cut -f2 -d">" | cut -f1 -d"<"`
if [ "$code" != "" ]
    then
    echo "Codigo de error: "$code
    echo "Mensaje de error: "$message
    exit
fi

xmlb64=`grep "<xml xsi:type=\"xsd:string\">.*<.xml>" $FILE_RESPONSE | sed -e "s/^.*<xml/<xml/" | cut -f2 -d">"| cut -f1 -d"<"`
echo `echo $xmlb64 | base64 --decode > $cfdixml`

echo "Timbrado generado con exito"
echo "El comprobante lo encuentra en el archivo $cfdixml"

if [ "$GENERARPDF" == "true" ]
    then
    pdfb64=`grep "<pdf xsi:type=\"xsd:string\">.*<.pdf>" $FILE_RESPONSE | sed -e "s/^.*<pdf/<pdf/" | cut -f2 -d">"| cut -f1 -d"<"`
    echo `echo $pdfb64 | base64 --decode > $cfdipdf`
    echo "El PDF lo encuentra en $cfdipdf"
fi