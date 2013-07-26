#!/bin/bash
# Ejemplo de timbrado desde Bash

########### Notas ############
## Instalar el paquete curl ##
##############################

### Declaracion de Variables
USERID="UsuarioPruebasWS"
USERPASS="b9ec2afa3361a59af4b4d102d3f704eabdf097d4"
RFC="ESI920427886"
URLTIMBRADO="https://t1demo.facturacionmoderna.com/timbrado/soap"
FILE_SOAPREQUEST="soap_request.xml"
GENERARTXT="false"
GENERARPDF="true"
GENERARCBB="false"
FILE_XML="XmlUTF8.xml"
XSLTFILE="utilerias/xslt32/cadenaoriginal_3_2.xslt"
KEYFILE="utilerias/certificados/20001000000200000192.key"
CERTFILE="utilerias/certificados/20001000000200000192.cer"
PEMFILE="utilerias/certificados/20001000000200000192.key.pem"
PASS="12345678a"
TMP="tmp.txt"
cfdixml="cfdi.xml"
cfdipdf="cfdi.pdf"
FILE_RESPONSE="response.xml"
code=""
###

## Crear Layout
FILE=$(cat<<EOF
<?xml version="1.0" encoding="utf-8"?>
<cfdi:Comprobante xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv32.xsd" xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema" version="3.2" serie="AA" folio="4" fecha="2013-07-12T10:12:58" sello="" formaDePago="Pago en una sola exhibición" noCertificado="" certificado="" condicionesDePago="Contado" subTotal="1498.00" descuento="0.00" Moneda="MXN" total="1737.68" tipoDeComprobante="ingreso" metodoDePago="Cheque" LugarExpedicion="San Pedro Garza García, Nuevo León, México" NumCtaPago="No identificado">
  <cfdi:Emisor rfc="ESI920427886" nombre="FACTURACION MODERNA SA DE CV">
    <cfdi:DomicilioFiscal calle="RIO GUADALQUIVIR" noExterior="238" colonia="ORIENTE DEL VALLE" municipio="San Pedro Garza García" estado="Nuevo León" pais="México" codigoPostal="66220"/>
    <cfdi:RegimenFiscal Regimen="REGIMEN GENERAL DE LEY PERSONAS MORALES"/>
  </cfdi:Emisor>
  <cfdi:Receptor rfc="XAXX010101000" nombre="PUBLICO EN GENERAL">
    <cfdi:Domicilio calle="CERRADA DE AZUCENAS" noExterior="109" colonia="REFORMA" municipio="Oaxaca de Juárez" estado="Oaxaca" pais="México" codigoPostal="68050"/>
  </cfdi:Receptor>
  <cfdi:Conceptos>
    <cfdi:Concepto cantidad="3" unidad="PIEZA" descripcion="CAJA DE HOJAS BLANCAS TAMAÑO CARTA" valorUnitario="450.00" importe="1350.00"/>
    <cfdi:Concepto cantidad="8" unidad="PIEZA" descripcion="RECOPILADOR PASTA DURA 3 ARILLOS" valorUnitario="18.50" importe="148.00"/>
  </cfdi:Conceptos>
  <cfdi:Impuestos totalImpuestosTrasladados="239.68">
    <cfdi:Traslados>
      <cfdi:Traslado impuesto="IVA" tasa="16" importe="239.68"/>
    </cfdi:Traslados>
  </cfdi:Impuestos> 
 
</cfdi:Comprobante>
EOF
)

echo $FILE > $FILE_XML

## Generar la cadena Original
cadena=`xsltproc $XSLTFILE $FILE_XML > $TMP`

## Obtener sello del comprobante
sello=`openssl dgst -sha1 -sign $PEMFILE $TMP | openssl enc -base64 -A > $TMP`
sello=`sed -e "s/\\//\\\\\\\\\//g" $TMP`

## Obtener contenido del certificado en base 64
certificado=`openssl enc -base64 -A -in $CERTFILE > $TMP`
certificado=`sed -e "s/\\//\\\\\\\\\//g" $TMP`

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

## Agrear Informacion del Sello al XML original
nodo=`grep " certificado=\".*\"" $FILE_XML | sed -e "s/^.* certificado/certificado/" | cut -f1 -d" "`
sed -e "s/$nodo/certificado=\"$certificado\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

nodo=`grep " noCertificado=\".*\"" $FILE_XML | sed -e "s/^.* noCertificado/noCertificado/" | cut -f1 -d" "`
sed -e "s/$nodo/noCertificado=\"$numcert\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

nodo=`grep " sello=\".*\"" $FILE_XML | sed -e "s/^.* sello/sello/" | cut -f1 -d" "`
sed -e "s/$nodo/sello=\"$sello\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

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