/***************************************************************************
                 factteso_general.qs  -  description
                             -------------------
    begin                : mie nov 23 2005
    copyright            : (C) 2004 by InfoSiAL S.L.
    email                : mail@infosial.com
 ***************************************************************************/
/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

/** @file */

/** @class_declaration interna */
////////////////////////////////////////////////////////////////////////////
//// DECLARACION ///////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
//// INTERNA /////////////////////////////////////////////////////
class interna {
	var ctx:Object;
	function interna( context ) { this.ctx = context; }
	function main() {
		this.ctx.interna_main();
	}
	function init() {
		this.ctx.interna_init();
	}
}
//// INTERNA /////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////

/** @class_declaration oficial */
//////////////////////////////////////////////////////////////////
//// OFICIAL /////////////////////////////////////////////////////
class oficial extends interna {
	function oficial( context ) { interna( context ); }
	function bufferChanged(fN:String) {
		return this.ctx.oficial_bufferChanged(fN);
	}
    function tbnCalcularDatosCuenta_clicked() {
        return this.ctx.oficial_tbnCalcularDatosCuenta_clicked();
    }
}
//// OFICIAL /////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////

/** @class_declaration head */
/////////////////////////////////////////////////////////////////
//// DESARROLLO /////////////////////////////////////////////////
class head extends oficial {
	function head( context ) { oficial ( context ); }
}
//// DESARROLLO /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

/** @class_declaration ifaceCtx*/
/////////////////////////////////////////////////////////////////
//// INTERFACE  /////////////////////////////////////////////////
class ifaceCtx extends head {
	function ifaceCtx( context ) { head( context ); }
}

const iface = new ifaceCtx( this );
//// INTERFACE  /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

/** @class_definition interna */
////////////////////////////////////////////////////////////////////////////
//// DEFINICION ////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
//// INTERNA /////////////////////////////////////////////////////
/**
\C Los datos generales son �nicos, por tanto formulario de no presenta los botones de navegaci�n por registros.
\end

\D La gesti�n del formulario se hace de forma manual mediante el objeto f (FLFormSearchDB)
\end
\end */
function interna_main()
{
	var f:Object = new FLFormSearchDB("factteso_general");
	var cursor:FLSqlCursor = f.cursor();

	cursor.select();
	if (!cursor.first())
		cursor.setModeAccess(cursor.Insert);
	else
		cursor.setModeAccess(cursor.Edit);

	f.setMainWidget();
	if (cursor.modeAccess() == cursor.Insert)
		f.child("pushButtonCancel").setDisabled(true);
	cursor.refreshBuffer();
	var commitOk:Boolean = false;
	var acpt:Boolean;
	cursor.transaction(false);
	while (!commitOk) {
		acpt = false;
		f.exec("id");
		acpt = f.accepted();
		if (!acpt) {
			if (cursor.rollback())
				commitOk = true;
		} else {
			if (cursor.commitBuffer()) {
				cursor.commit();
				commitOk = true;
			}
		}
		f.close();
	}
}

function interna_init()
{
	var util:FLUtil = new FLUtil;
	var cursor:FLSqlCursor = this.cursor();

	connect (cursor, "bufferChanged(QString)", this, "iface.bufferChanged");
    connect (this.child("tbnCalcularDatosCuenta"), "clicked()", this, "iface.tbnCalcularDatosCuenta_clicked");
	
	this.iface.bufferChanged("pagoindirecto");
}
//// INTERNA /////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

/** @class_definition oficial */
//////////////////////////////////////////////////////////////////
//// OFICIAL /////////////////////////////////////////////////////
function oficial_bufferChanged(fN:String)
{
	var util:FLUtil = new FLUtil;
	var cursor:FLSqlCursor = this.cursor();
	switch (fN) {
		case "pagoindirecto": {
			var msg:String;
			if (cursor.valueBuffer("pagoindirecto") == true) {
				msg = util.translate("scripts", "Al incluir un recibo de cliente en una remesa, el correspondiente asiento de pago se asigna a la subcuenta de Efectos comerciales de gesti�n de cobro (E.C.G.C.) asociada a la cuenta bancaria de la remesa. Cuando se recibe la confirmaci�n del banco el usuario inserta un registro de pago para la remesa completa, que lleva las partidas de E.C.G.C. a la subcuenta de la cuenta bancaria.");
			} else {
				msg = util.translate("scripts", "Al incluir un recibo de cliente en una remesa, el correspondiente asiento de pago se asigna directamente a la subcuenta de la cuenta bancaria indicada en la remesa.");
			}
			this.child("lblDesPagoIndirecto").text = msg;
			break;
		}
	}
}

function oficial_tbnCalcularDatosCuenta_clicked()
{
    var _i = this.iface;
    
    var res = MessageBox.information(sys.translate("Se van a calcular los d�gitos de control, los c�digos de cuenta, y el IBAN de todas las cuentas de empresa, clientes, y proveedores.\n�Quieres continuar?\n\nNota: si el c�digo de pa�s en la cuenta est� vac�o, se supondr� que es de Espa�a.\nSi tiene cuentas de otros pa�ses debe revisarlas antes e informar su correspondiente c�digo de pa�s"), MessageBox.Yes, MessageBox.No);
    if (res != MessageBox.Yes) {
        return;
    }
    
    var codigoES = AQUtil.sqlSelect("paises","codpais","codpais = 'ES' AND codiso = 'ES'");
    var paisES;
        
    if(!codigoES || codigoES == "") {
        paisES = AQUtil.sqlSelect("paises","codpais","codiso = 'ES' ORDER BY codpais");
        
        if(!paisES || paisES == "") {
            MessageBox.information(sys.translate("Lo siento, necesita tener un pa�s con c�digo ISO 'ES'."), MessageBox.Ok, MessageBox.NoButton);
            return false;
        }
    }
    else {
        paisES = codigoES;
    }
    
    var aTablas = ["cuentasbanco","cuentasbcocli","cuentasbcopro"];
    var aTablasError = ["Cta. Empresa", "Cta. Cliente", "Cta. Proveedor"];
    var nombresTabla = [sys.translate("cuentas de empresa"), sys.translate("cuentas de clientes"), sys.translate("cuentas de proveedores")];
    
    var aErrorCta = [];
    var aErrorDesc = [];
    var aErrorTab = [];
    
    for(var i = 0; i < aTablas.length; i++) {
        var paso = 0;
        
        var curCuentas = new FLSqlCursor(aTablas[i]);
        curCuentas.select();
        
        var totalPasos = curCuentas.size();
        
        if(totalPasos == 0) {
            continue;
        }
        
        AQUtil.createProgressDialog(sys.translate("Calculando datos de IBAN en las %1...").arg(nombresTabla[i]), totalPasos);
        
        while(curCuentas.next()) {
            AQUtil.setProgress(++paso);
            curCuentas.setModeAccess(curCuentas.Edit);
            curCuentas.refreshBuffer();
            
            var codCuenta = curCuentas.valueBuffer("codcuenta");
            var desc = curCuentas.valueBuffer("descripcion");
            var codPais = curCuentas.valueBuffer("codpais");
        
            if (curCuentas.isNull("codpais") || (codPais == "ES" && paisES && paisES != "") || AQUtil.sqlSelect("paises", "codiso", "codpais = '" + curCuentas.valueBuffer("codpais") + "'") == "ES") {
                if (curCuentas.isNull("codpais") || (codPais == "ES" && paisES && paisES != "")) {
                    curCuentas.setValueBuffer("codpais", paisES);
                }
                
                var entidad = curCuentas.valueBuffer("ctaentidad");
                var agencia = curCuentas.valueBuffer("ctaagencia");
                var cuenta = curCuentas.valueBuffer("cuenta");
                
                if(!entidad || !agencia || !cuenta) {
                    aErrorCta.push(codCuenta);
                    aErrorDesc.push(desc);
                    aErrorTab.push(aTablasError[i]);
                    continue;
                }
                
                if(entidad.length != 4 || agencia.length != 4 || cuenta.length != 10) {
                    aErrorCta.push(codCuenta);
                    aErrorDesc.push(desc);
                    aErrorTab.push(aTablasError[i]);
                    continue;
                }
                
                if(isNaN(parseFloat(entidad)) || isNaN(parseFloat(entidad)) || isNaN(parseFloat(entidad))) {
                    aErrorCta.push(codCuenta);
                    aErrorDesc.push(desc);
                    aErrorTab.push(aTablasError[i]);
                    continue;
                }
                
                curCuentas.setValueBuffer("ctadc", formRecordcuentasbanco.iface.pub_commonCalculateField("ctadc", curCuentas));
                curCuentas.setValueBuffer("codigocuenta", formRecordcuentasbanco.iface.pub_commonCalculateField("codigocuenta_es", curCuentas));
            }
            curCuentas.setValueBuffer("iban", formRecordcuentasbanco.iface.pub_commonCalculateField("iban", curCuentas));
            curCuentas.setValueBuffer("bic", formRecordcuentasbanco.iface.pub_commonCalculateField("bic", curCuentas));
            
            
            if (!curCuentas.commitBuffer()) {
                AQUtil.destroyProgressDialog();
                MessageBox.information(sys.translate("Error en el c�lculo de los datos de la cuenta %1 en %2"), MessageBox.Ok, MessageBox.NoButton);
                return;
            }           
        } 
        
        AQUtil.destroyProgressDialog();
    }
    
    if(aErrorCta.length == 0) {
        MessageBox.information(sys.translate("Los datos de las cuentas han sido recalculados con �xito."), MessageBox.Ok, MessageBox.NoButton);
    }
    else if(aErrorCta.length < 20) {
        var mensaje = "Las siguientes cuentas no han sido recalculadas:\n";
        
        for(var i = 0; i < aErrorCta.length; i++) {
            mensaje += "\n     " + aErrorTab[i] + " - " + aErrorCta[i] + " - " + aErrorDesc[i] + ".";
        }
        
        MessageBox.information(sys.translate(mensaje), MessageBox.Ok, MessageBox.NoButton);
    }
    else {
        MessageBox.information(sys.translate("Algunas cuentas no se han podido calcular.\nIntroduzca una ruta para guardar un archivo que las contenga:"), MessageBox.Ok, MessageBox.NoButton);
        
        var archivo = FileDialog.getSaveFileName("*.txt");
        
        if(!archivo || archivo == "") {
            return false;
        }
        
        if(!archivo.endsWith(".txt")) {
            archivo += ".txt";
        }
        
        var file = new File(archivo);
        file.open(File.WriteOnly);
        
        var mensaje = "Las siguientes cuentas no han sido recalculadas:\n";
        
        for(var i = 0; i < aErrorCta.length; i++) {
            mensaje += "\n     " + aErrorTab[i] + " - " + aErrorCta[i] + " - " + aErrorDesc[i] + ".";
        }
        
        file.write(mensaje);
        file.close();
        
        MessageBox.information(sys.translate("El fichero se ha generado con �xito en %1"), MessageBox.Ok, MessageBox.NoButton);
    }
}
//// OFICIAL /////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////

/** @class_definition head */
/////////////////////////////////////////////////////////////////
//// DESARROLLO /////////////////////////////////////////////////

//// DESARROLLO /////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////
