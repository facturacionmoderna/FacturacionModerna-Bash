#!/bin/bash
# Ejemplo de timbrado desde Bash

########### Notas ############
## Instalar el paquete curl ##
##############################

### Declaracion de Variables
DATE=`date +'%Y-%m-%dT%H:%M:00'`
USERID="UsuarioPruebasWS"
USERPASS="b9ec2afa3361a59af4b4d102d3f704eabdf097d4"
RFC="TCM970625MB1"
URLTIMBRADO="https://t1demo.facturacionmoderna.com/timbrado/soap"
FILE_SOAPREQUEST="soap_request.xml"
GENERARTXT="false"
GENERARPDF="true"
GENERARCBB="false"
FILE_XML="XmlUTF8.xml"
XSLTFILE="utilerias/xslt33/cadenaoriginal_3_3.xslt"
KEYFILE="utilerias/certificados/20001000000300022762.key"
CERTFILE="utilerias/certificados/20001000000300022762.cer"
PEMFILE="utilerias/certificados/20001000000300022762.key.pem"
PASS="12345678a"
TMP="tmp.txt"
cfdixml="cfdi.xml"
cfdipdf="cfdi.pdf"
FILE_RESPONSE="response.xml"
code=""
###

## Crear Layout
FILE=$(cat<<EOF
<?xml version="1.0" encoding="UTF-8"?>
<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd" Version="3.3" Serie="A" Folio="01" Fecha="$DATE" Sello="" FormaPago="03" NoCertificado="" Certificado="" CondicionesDePago="CONTADO" SubTotal="1850" Descuento="175.00" Moneda="MXN" Total="1943.00" TipoDeComprobante="I" MetodoPago="PUE" LugarExpedicion="68050">
  <cfdi:Emisor Rfc="TCM970625MB1" Nombre="FACTURACION MODERNA SA DE CV" RegimenFiscal="601"/>
  <cfdi:Receptor Rfc="XAXX010101000" Nombre="PUBLICO EN GENERAL" UsoCFDI="G01"/>
  <cfdi:Conceptos>
    <cfdi:Concepto ClaveProdServ="01010101" NoIdentificacion="AULOG001" Cantidad="5" ClaveUnidad="H87" Unidad="Pieza" Descripcion="Aurriculares USB Logitech" ValorUnitario="350.00" Importe="1750.00" Descuento="175.00">
      <cfdi:Impuestos>
        <cfdi:Traslados>
          <cfdi:Traslado Base="1575.00" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="252.00"/>
      </cfdi:Traslados>
  </cfdi:Impuestos>
</cfdi:Concepto>
<cfdi:Concepto ClaveProdServ="43201800" NoIdentificacion="USB" Cantidad="1" ClaveUnidad="H87" Unidad="Pieza" Descripcion="Memoria USB 32gb marca Kingston" ValorUnitario="100.00" Importe="100.00">
  <cfdi:Impuestos>
    <cfdi:Traslados>
      <cfdi:Traslado Base="100.00" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="16.00"/>
  </cfdi:Traslados>
</cfdi:Impuestos>
</cfdi:Concepto>
</cfdi:Conceptos>
<cfdi:Impuestos TotalImpuestosTrasladados="268.00">
    <cfdi:Traslados>
      <cfdi:Traslado Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="268.00"/>
  </cfdi:Traslados>
</cfdi:Impuestos>
</cfdi:Comprobante>
EOF
)

echo $FILE > $FILE_XML

## Obtener el numero del certificado
numcert=`openssl x509 -inform DER -in $CERTFILE -noout -serial`
numcert=`echo $numcert | cut -d"=" -f 2`
t=${#numcert}
for i in `seq 1 $t`
do
    n=$((i%2))
    if [ $n -eq 0 ]
        then
        l1=`echo $numcert | cut -c $i`
        str=$str$l1
    fi
done
numcert=$str
# Agregar el numero de certificado al xml
nodo=`grep " NoCertificado=\".*\"" $FILE_XML | sed -e "s/^.* NoCertificado/NoCertificado/" | cut -f1 -d" "`
sed -e "s/$nodo/NoCertificado=\"$numcert\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`
## Obtener contenido del certificado en base 64
certificado=`openssl enc -base64 -A -in $CERTFILE > $TMP`
certificado=`sed -e "s/\\//\\\\\\\\\//g" $TMP`
# Agregar la informacion del certificado al xml
nodo=`grep " Certificado=\".*\"" $FILE_XML | sed -e "s/^.* Certificado/Certificado/" | cut -f1 -d" "`
sed -e "s/$nodo/Certificado=\"$certificado\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

## Obtener sello del comprobante
sello=`xsltproc $XSLTFILE $FILE_XML | openssl dgst -sha256 -sign $PEMFILE | openssl enc -base64 -A > $TMP`
sello=`sed -e "s/\\//\\\\\\\\\//g" $TMP`

## Agrear Informacion del Sello al XML original
nodo=`grep " Sello=\".*\"" $FILE_XML | sed -e "s/^.* Sello/Sello/" | cut -f1 -d" "`
sed -e "s/$nodo/Sello=\"$sello\"/g" $FILE_XML > $TMP
## cmd=`mv $TMP $FILE_XML`
cmd=`cp $TMP $FILE_XML`

## Convertir a base 64 el XML para ser timbrado
B64STR=`base64 -i $FILE_XML`

## Armar la peticion SOAP
SOAP_REQUEST=$( cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope" xmlns:ns1="https://t1demo.facturacionmoderna.com/timbrado/soap" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:enc="http://www.w3.org/2003/05/soap-encoding"><env:Body><ns1:requestTimbrarCFDI env:encodingStyle="http://www.w3.org/2003/05/soap-encoding"><param0 xsi:type="enc:Struct"><UserPass xsi:type="xsd:string">$USERPASS</UserPass><UserID xsi:type="xsd:string">$USERID</UserID><emisorRFC xsi:type="xsd:string">$RFC</emisorRFC><text2CFDI xsi:type="xsd:string">$B64STR</text2CFDI><generarTXT xsi:type="xsd:boolean">$GENERARTXT</generarTXT><generarPDF xsi:type="xsd:string">$GENERARPDF</generarPDF><generarCBB xsi:type="xsd:boolean">$GENERARCBB</generarCBB></param0></ns1:requestTimbrarCFDI></env:Body></env:Envelope>
EOF
)

echo $SOAP_REQUEST > $FILE_SOAPREQUEST
echo "solicitando Timbrado..."
soap_response=`curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO`
#echo $soap_response

echo $soap_response > $FILE_RESPONSE

## Verificar que no haya ocurrido un error
code=`grep "<env:Body>.*<.env:Body>" $FILE_RESPONSE | sed -e "s/^.*<env:Value/<env:Value/" | cut -f2 -d">" | cut -f1 -d"<"`
message=`grep "<env:Body>.*<.env:Body>" $FILE_RESPONSE | sed -e "s/^.*<env:Text/<env:Text/" | cut -f2 -d">" | cut -f1 -d"<"`
if [ "$code" != "" ]
    then
    echo "Codigo de error: "$code
    echo "Mensaje de error: "$message
    exit
fi

## Decodificar XML
xmlb64=`grep "<xml xsi:type=\"xsd:string\">.*<.xml>" $FILE_RESPONSE | sed -e "s/^.*<xml/<xml/" | cut -f2 -d">"| cut -f1 -d"<"`
echo `echo $xmlb64 | base64 --decode > $cfdixml`

echo "Timbrado generado con exito"
echo "El comprobante lo encuentra en $cfdixml"

if [ "$GENERARPDF" == "true" ]
    then
    pdfb64=`grep "<pdf xsi:type=\"xsd:string\">.*<.pdf>" $FILE_RESPONSE | sed -e "s/^.*<pdf/<pdf/" | cut -f2 -d">"| cut -f1 -d"<"`
    echo `echo $pdfb64 | base64 --decode > $cfdipdf`
    echo "El PDF lo encuentra en $cfdipdf"
fi