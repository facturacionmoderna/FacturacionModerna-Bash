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
GENERARPDF="false"
GENERARCBB="false"
FILE_XML="XmlUTF8.xml"
XSLTFILE="utilerias/xslt32/cadenaoriginal_3_2.xslt"
KEYFILE="utilerias/certificados/20001000000200000192.key"
CERTFILE="utilerias/certificados/20001000000200000192.cer"
PEMFILE="utilerias/certificados/20001000000200000192.key.pem"
PASS="12345678a"
TMP="tmp.txt"
cfdixml="cfdi.xml"
###

## Crear Layout
FILE=$(cat<<EOF
<?xml version="1.0" encoding="UTF-8"?>
<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                  xmlns:xs="http://www.w3.org/2001/XMLSchema" xsi:schemaLocation="http://www.sat.gob.mx/cfd/3
                  http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv32.xsd" version="3.2" fecha="2013-07-23T09:12:00" folio="101"
                  serie="AX" subTotal="100.00" descuento="0.00" total="116.00" Moneda="MXN" TipoCambio="0.00"
                  condicionesDePago="Pago en una sola Exhibición" tipoDeComprobante="ingreso" noCertificado="" certificado=""
                  formaDePago="Contado" metodoDePago="Efectivo" NumCtaPago="0009 - Banamex" sello="" LugarExpedicion="San Pedro Garza García">
  <cfdi:Emisor nombre="COMERCIALIZADORA SA DE CV" rfc="ESI920427886">
    <cfdi:DomicilioFiscal calle="Calzada del Valle" noExterior="90" noInterior="int-10" colonia="Col. Del Valle"
                          municipio="San Pedro Garza Garcia." estado="Nuevo León" pais="México" codigoPostal="76888"/>
    <cfdi:ExpedidoEn calle="Calzada del Valle(Sucursal)" noExterior="90" noInterior="int-10" colonia="Col. Del Valle"
                          municipio="San Pedro Garza Garcia." estado="Nuevo León" pais="México" codigoPostal="76888"/>
    <cfdi:RegimenFiscal Regimen="PERSONA MORAL REGIMEN GENERAL DE LEY."/>
  </cfdi:Emisor>
  <cfdi:Receptor nombre="FIRST DATA PROCUREMENTS MEXICO, S DE R.L. DE CV" rfc="FPD020724PKA">
    <cfdi:Domicilio calle="Reforma" noExterior="1000" noInterior="Piso 2, Int-5" colonia="Centro" municipio="Alvaro Obregón"
                    estado="Distrito Federal" pais="México" codigoPostal="60000"/>
  </cfdi:Receptor>
  <cfdi:Conceptos>
    <cfdi:Concepto noIdentificacion="7899701" unidad="Pieza" descripcion="Caja de Chocolates" cantidad="1.00" valorUnitario="50.00" importe="50.00"/>    <cfdi:Concepto noIdentificacion="8789788" unidad="No aplica" descripcion="Envio" cantidad="1.00" valorUnitario="50.00" importe="50.00"/>
  </cfdi:Conceptos>
  <cfdi:Impuestos totalImpuestosRetenidos="200.00" totalImpuestosTrasladados="16.00">
    <cfdi:Retenciones>
      <cfdi:Retencion impuesto="ISR" importe="200.00"/>
    </cfdi:Retenciones>
    <cfdi:Traslados>
      <cfdi:Traslado impuesto="IVA" tasa="16.00" importe="16.00"/>
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
nodo=`grep "\scertificado=\".*\"" $FILE_XML | sed -e "s/^.*\scertificado/certificado/" | cut -f1 -d" "`
sed -e "s/$nodo/certificado=\"$certificado\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

nodo=`grep "\snoCertificado=\".*\"" $FILE_XML | sed -e "s/^.*\snoCertificado/noCertificado/" | cut -f1 -d" "`
sed -e "s/$nodo/noCertificado=\"$numcert\"/g" $FILE_XML > $TMP
cmd=`mv $TMP $FILE_XML`

nodo=`grep "\ssello=\".*\"" $FILE_XML | sed -e "s/^.*\ssello/sello/" | cut -f1 -d" "`
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
echo "curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO"
soap_response=`curl --data  @$FILE_SOAPREQUEST --header "Content-Type: text/xml; charset=utf-8" $URLTIMBRADO`
#echo $soap_response

FILE_RESPONSE="response.xml"
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
xmlb64=`grep "<xml\sxsi:type=\"xsd:string\">.*<.xml>" $FILE_RESPONSE | sed -e "s/^.*<xml/<xml/" | cut -f2 -d">"| cut -f1 -d"<"`
echo `echo $xmlb64 | base64 --decode > $cfdixml`
echo "Timbrado generado con exito"
echo "El comprobante lo encuentra en el archivo $cfdixml"