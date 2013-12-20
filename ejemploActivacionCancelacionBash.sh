#!/bin/bash
# Ejemplo de Activacion de WS de Cancelacion

########### Notas ############
## Instalar el paquete curl ##
##############################

### Declaracion de Variables
USERID="UsuarioPruebasWS"
USERPASS="b9ec2afa3361a59af4b4d102d3f704eabdf097d4"
RFC="ESI920427886"
FILE_CER="utilerias/certificados/20001000000200000192.cer"
FILE_KEY="utilerias/certificados/20001000000200000192.key"
PASS_KEY="12345678a"
B64CER="";
B64KEY=""
URLTIMBRADO="https://t1demo.facturacionmoderna.com/timbrado/soap"
FILE_SOAPREQUEST="soap_request.xml"
FILE_RESPONSE="response.xml"
###

B64CER=`base64 -i $FILE_CER`
B64KEY=`base64 -i $FILE_KEY`

SOAP_REQUEST=$( cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" xmlns:ns1="https://t1demo.facturacionmoderna.com/timbrado/soap" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:enc="http://www.w3.org/2003/05/soap-encoding"><env:Body><ns1:activarCancelacion env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"><param0 xsi:type="enc:Struct"><UserPass xsi:type="xsd:string">$USERPASS</UserPass><UserID xsi:type="xsd:string">$USERID</UserID><emisorRFC xsi:type="xsd:string">$RFC</emisorRFC><archivoKey xsi:type="xsd:string">$B64KEY</archivoKey><archivoCer xsi:type="xsd:string">$B64CER</archivoCer><clave xsi:type="xsd:string">$PASS_KEY</clave></param0></ns1:activarCancelacion></env:Body></env:Envelope>
EOF
)

echo $SOAP_REQUEST > $FILE_SOAPREQUEST
echo "Solicitando activacion..."
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

echo `grep "<mensaje xsi:type=\"xsd:string\">.*<.mensaje>" $FILE_RESPONSE | sed -e "s/^.*<mensaje/<mensaje/" | cut -f2 -d">"| cut -f1 -d"<"`