{*******************************************************************************
  作者: dmzn@163.com 2017-09-26
  描述: 开提货单
*******************************************************************************}
unit UFormBill;

{$I Link.Inc}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  UFormNormal, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, ComCtrls, cxContainer, cxEdit, cxCheckBox,
  cxMaskEdit, cxDropDownEdit, cxTextEdit, cxListView, cxMCListBox,
  dxLayoutControl, StdCtrls, cxMemo, cxLabel, cxCalendar;

type
  TfFormBill = class(TfFormNormal)
    dxGroup2: TdxLayoutGroup;
    dxLayout1Item3: TdxLayoutItem;
    ListInfo: TcxMCListBox;
    EditValue: TcxTextEdit;
    dxLayout1Item8: TdxLayoutItem;
    EditTruck: TcxTextEdit;
    dxLayout1Item9: TdxLayoutItem;
    EditStock: TcxComboBox;
    dxLayout1Item7: TdxLayoutItem;
    EditLading: TcxComboBox;
    dxLayout1Item12: TdxLayoutItem;
    EditFQ: TcxTextEdit;
    dxLayout1Item5: TdxLayoutItem;
    dxLayout1Item6: TdxLayoutItem;
    EditType: TcxComboBox;
    PrintGLF: TcxCheckBox;
    dxLayout1Item13: TdxLayoutItem;
    dxLayout1Item14: TdxLayoutItem;
    PrintHY: TcxCheckBox;
    dxLayout1Group4: TdxLayoutGroup;
    dxLayout1Group3: TdxLayoutGroup;
    dxLayout1Group6: TdxLayoutGroup;
    dxLayout1Group2: TdxLayoutGroup;
    cxLabel1: TcxLabel;
    dxLayout1Item4: TdxLayoutItem;
    EditPhone: TcxTextEdit;
    dxLayout1Item10: TdxLayoutItem;
    EditUnloading: TcxMemo;
    dxLayout1Item11: TdxLayoutItem;
    EditDate: TcxDateEdit;
    dxLayout1Item15: TdxLayoutItem;
    dxLayout1Group5: TdxLayoutGroup;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BtnOKClick(Sender: TObject);
    procedure EditLadingKeyPress(Sender: TObject; var Key: Char);
    procedure EditFQPropertiesEditValueChanged(Sender: TObject);
  protected
    { Protected declarations }
    FMsgNo: Cardinal;
    FBuDanFlag: string;
    //补单标记
    procedure LoadFormData;
    //载入数据
  public
    { Public declarations }
    class function CreateForm(const nPopedom: string = '';
      const nParam: Pointer = nil): TWinControl; override;
    class function FormID: integer; override;
    function OnVerifyCtrl(Sender: TObject; var nHint: string): Boolean; override;
  end;

implementation

{$R *.dfm}

uses
  ULibFun, DB, IniFiles, UMgrControl, UFormBase, UDataModule, UAdjustForm,
  UBusinessConst, USysPopedom, USysBusiness, USysDB, USysGrid, USysConst,
  UBusinessPacker, UFormWait;

var
  gBillItem: TLadingBillItem;
  //提单数据

class function TfFormBill.CreateForm(const nPopedom: string;
  const nParam: Pointer): TWinControl;
var nBool,nBuDan: Boolean;
    nDef: TLadingBillItem;
    nP: PFormCommandParam;
begin
  Result := nil;
  if GetSysValidDate < 1 then Exit;

  nP := nil;
  try
    if not Assigned(nParam) then
    begin
      New(nP);
      FillChar(nP^, SizeOf(TFormCommandParam), #0);
    end else nP := nParam;

    nBuDan := nPopedom = 'MAIN_D04';
    FillChar(nDef, SizeOf(nDef), #0);
    nP.FParamE := @nDef;

    CreateBaseFormItem(cFI_FormGetZhika, nPopedom, nP);
    if (nP.FCommand <> cCmd_ModalResult) or (nP.FParamA <> mrOK) then Exit;
    gBillItem := nDef;
  finally
    if not Assigned(nParam) then Dispose(nP);
  end;

  with TfFormBill.Create(Application) do
  try
    Caption := '开提货单';
    FMsgNo := GetTickCount;

    if nBuDan then //补单
         FBuDanFlag := sFlag_Yes
    else FBuDanFlag := sFlag_No;

    nBool := not gPopedomManager.HasPopedom(nPopedom, sPopedom_Edit);
    EditLading.Properties.ReadOnly := nBool;
    LoadFormData;

    if Assigned(nParam) then
    with PFormCommandParam(nParam)^ do
    begin
      FCommand := cCmd_ModalResult;
      FParamA := ShowModal;

      if FParamA = mrOK then
           FParamB := gBillItem.FID
      else FParamB := '';
    end else ShowModal;
  finally
    Free;
  end;
end;

class function TfFormBill.FormID: integer;
begin
  Result := cFI_FormBill;
end;

procedure TfFormBill.FormCreate(Sender: TObject);
var nStr: string;
    nIni: TIniFile;
begin
  nIni := TIniFile.Create(gPath + sFormConfig);
  try
    nStr := nIni.ReadString(Name, 'FQLabel', '');
    if nStr <> '' then
      dxLayout1Item5.Caption := nStr;
    //xxxxx

    PrintHY.Checked := nIni.ReadBool(Name, 'PrintHY', False);
    //随车开单
    LoadMCListBoxConfig(Name, ListInfo, nIni);
  finally
    nIni.Free;
  end;

  {$IFDEF PrintGLF}
  dxLayout1Item13.Visible := True;
  {$ELSE}
  dxLayout1Item13.Visible := False;
  PrintGLF.Checked := False;
  {$ENDIF}

  {$IFDEF PrintHYEach}
  dxLayout1Item14.Visible := True;
  {$ELSE}
  dxLayout1Item14.Visible := False;
  PrintHY.Checked := False;
  {$ENDIF}

  AdjustCtrlData(Self);
end;

procedure TfFormBill.FormClose(Sender: TObject; var Action: TCloseAction);
var nIni: TIniFile;
begin
  nIni := TIniFile.Create(gPath + sFormConfig);
  try
    nIni.WriteBool(Name, 'PrintHY', PrintHY.Checked);
    SaveMCListBoxConfig(Name, ListInfo, nIni);
  finally
    nIni.Free;
  end;

  ReleaseCtrlData(Self);
end;

//Desc: 回车键
procedure TfFormBill.EditLadingKeyPress(Sender: TObject; var Key: Char);
var nP: TFormCommandParam;
begin
  if Key = Char(VK_RETURN) then
  begin
    Key := #0;

    if Sender = EditTruck then ActiveControl := EditValue else
    if Sender = EditPhone then ActiveControl := EditUnloading else
    if Sender = EditUnloading then ActiveControl := BtnOK else
    //xxxxx
    
    if Sender = EditValue then
         ActiveControl := BtnOK
    else Perform(WM_NEXTDLGCTL, 0, 0);
  end;

  if (Sender = EditTruck) and (Key = Char(VK_SPACE)) then
  begin
    Key := #0;
    nP.FParamA := EditTruck.Text;
    CreateBaseFormItem(cFI_FormGetTruck, '', @nP);

    if (nP.FCommand = cCmd_ModalResult) and(nP.FParamA = mrOk) then
    begin
      EditTruck.Text := nP.FParamB;
      EditPhone.Text := nP.FParamD;
    end;
    EditTruck.SelectAll;
  end;

  if (Sender = EditUnloading) and (Key = Char(VK_SPACE)) then
  begin
    Key := #0;
    nP.FParamA := EditUnloading.Text;
    CreateBaseFormItem(cFI_FormGetUnloading, '', @nP);

    if (nP.FCommand = cCmd_ModalResult) and(nP.FParamA = mrOk) then
      EditUnloading.Text := nP.FParamB;
    EditUnloading.SelectAll;
  end;
end;

//------------------------------------------------------------------------------
//Desc: 载入界面数据
procedure TfFormBill.LoadFormData;
var nStr: string;
begin
  dxGroup1.AlignVert := avClient;
  dxGroup2.AlignVert := avBottom;

  EditDate.Date := Now();
  dxLayout1Item15.Visible := FBuDanFlag = sFlag_Yes;

  ActiveControl := EditTruck;
  EditStock.ItemIndex := 1; //水泥

  with gBillItem,ListInfo do
  begin
    Clear;
    Items.Add(Format('订单编号:%s %s', [Delimiter, FZhiKa]));
    Items.Add(Format('工厂代码:%s %s', [Delimiter, FStatus]));
    Items.Add(Format('工厂名称:%s %s', [Delimiter, FNextStatus]));

    Items.Add(Format('%s ', [Delimiter]));
    Items.Add(Format('客户编号:%s %s', [Delimiter, FCusID]));
    Items.Add(Format('客户名称:%s %s', [Delimiter, FCusName]));

    Items.Add(Format('%s ', [Delimiter]));
    Items.Add(Format('物料编号:%s %s', [Delimiter, FStockNo]));
    Items.Add(Format('物料名称:%s %s', [Delimiter, FStockName]));

    if FType = sFlag_Dai then nStr := '袋装' else nStr := '散装';
    Items.Add(Format('物料类型:%s %s', [Delimiter, nStr]));
    Items.Add(Format('预计可用:%s %.2f吨', [Delimiter, FValue]));
  end;
end;

//Desc: 保存封签号
procedure TfFormBill.EditFQPropertiesEditValueChanged(Sender: TObject);
var nIni: TIniFile;
begin
  inherited;
  nIni := TIniFile.Create(gPath + sFormConfig);
  try
    nIni.WriteString('EditFQ', GetCtrlData(EditStock), EditFQ.Text);
  finally
    nIni.Free;
  end;
end;

function TfFormBill.OnVerifyCtrl(Sender: TObject; var nHint: string): Boolean;
begin
  Result := True;

  if Sender = EditTruck then
  begin
    Result := Length(EditTruck.Text) > 2;
    nHint := '车牌号长度应大于2位';
  end else

  if Sender = EditLading then
  begin
    Result := EditLading.ItemIndex > -1;
    nHint := '请选择提货方式';
  end else

  if Sender = EditStock then
  begin
    Result := EditStock.ItemIndex > -1;
    nHint := '请选择库存地点';
  end else

  if Sender = EditFQ then
  begin
    EditFQ.Text := Trim(EditFQ.Text);
    Result := (Length(EditFQ.Text) > 0) or (not VerifyFQSumValue);
    nHint := '出厂编号不能为空';
  end else

  if Sender = EditValue then
  begin
    Result := IsNumber(EditValue.Text, True) and (StrToFloat(EditValue.Text)>0);
    nHint := '请填写有效的办理量';
    if not Result then Exit;
  end;
end;

//Desc: 保存
procedure TfFormBill.BtnOKClick(Sender: TObject);
var nPrint: Boolean;
    nList,nStocks: TStrings;
begin
  nStocks := TStringList.Create;
  nList := TStringList.Create;
  try
    nList.Clear;
    nPrint := False;
    LoadSysDictItem(sFlag_PrintBill, nStocks);
    //需打印品种

    with nList do
    begin
      if PrintGLF.Checked  then
           Values['PrintGLF'] := sFlag_Yes
      else Values['PrintGLF'] := sFlag_No;

      if PrintHY.Checked  then
           Values['PrintHY'] := sFlag_Yes
      else Values['PrintHY'] := sFlag_No;

      if (not nPrint) and (FBuDanFlag <> sFlag_Yes) then
        nPrint := nStocks.IndexOf(gBillItem.FStockNo) >= 0;
      //xxxxx

      Values['ZhiKa']        := gBillItem.FZhiKa;
      Values['Truck']        := EditTruck.Text;
      Values['Value']        := EditValue.Text;

      Values['Area']         := GetCtrlData(EditStock);
      Values['Lading']       := GetCtrlData(EditLading);
      Values['IsVIP']        := GetCtrlData(EditType);

      Values['Value']        := EditValue.Text;
      Values['Seal']         := EditFQ.Text;
      Values['BuDan']        := FBuDanFlag;
      Values['BuDanDate']    := Date2Str(EditDate.Date);

      Values['Phone']        := Trim(EditPhone.Text);
      Values['Unloading']    := Trim(EditUnloading.Text);
      Values['MsgNo']        := IntToStr(FMsgNo);
    end;

    ShowWaitForm(Self, '正在保存数据', True);
    try
      gBillItem.FID := SaveBill(PackerEncodeStr(nList.Text));
      //call mit bus
    finally
      CloseWaitForm;
    end;

    if gBillItem.FID = '' then Exit;
    //save failed
  finally
    nList.Free;
    nStocks.Free;
  end;

  if FBuDanFlag <> sFlag_Yes then
    SetBillCard(gBillItem.FID, EditTruck.Text, True);
  //办理磁卡

  if nPrint then
    PrintBillReport(gBillItem.FID, True);
  //print report
  
  ModalResult := mrOk;
  ShowMsg('提货单保存成功', sHint);
end;

initialization
  gControlManager.RegCtrl(TfFormBill, TfFormBill.FormID);
end.
