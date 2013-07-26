#!bin/bash

####Ejemplo para cancelar un CFDI

UUID="843B6B38-8189-4AA4-ADCC-4BEEB4424D1A"
USERID="UsuarioPruebasWS"
USERPASS="b9ec2afa3361a59af4b4d102d3f704eabdf097d4"
RFC="ESI920427886"
URLCANCELADO="https://t1demo.facturacionmoderna.com/timbrado/soap"
FILE_SOAPREQUEST="soap_request.xml"
FILE_RESPONSE="response.xml"

## Armar la peticion SOAP
SOAP_REQUEST=$( cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="https://t1demo.facturacionmoderna.com/timbrado/soap"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <SOAP-ENV:Body>
    <ns1:requestCancelarCFDI>
      <request xsi:type="SOAP-ENC:Struct">
        <uuid xsi:type="xsd:string">$UUID</uuid>
        <emisorRFC xsi:type="xsd:string">$RFC</emisorRFC>
        <UserID xsi:type="xsd:string">$USERID</UserID>
        <UserPass xsi:type="xsd:string">$USERPASS</UserPass>
      </request>
    </ns1:requestCancelarCFDI>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF
)
echo $SOAP_REQUEST > $FILE_SOAPREQUEST

echo "solicitando Cancelacion..."
soap_response=`curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLCANCELADO`

echo $soap_response > $FILE_RESPONSE

## Verificar que no haya ocurrido un error
code=""
code=`grep "<SOAP-ENV:Fault>.*<.SOAP-ENV:Fault>" $FILE_RESPONSE | sed -e "s/^.*<faultcode/<faultcode/" | cut -f2 -d">" | cut -f1 -d"<"`
message=`grep "<SOAP-ENV:Body>.*<.SOAP-ENV:Body>" $FILE_RESPONSE | sed -e "s/^.*<faultstring/<faultstring/" | cut -f2 -d">" | cut -f1 -d"<"`
if [ "$code" != "" ]
    then
    echo "Codigo de error: "$code
    echo "Mensaje de error: "$message
    exit
fi

echo "Cancelacion Exitosa"