{*******************************************************************************
  Copyright (C) Christian Ulrich info@cu-tec.de

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or commercial alternative
  contact us for more information

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
Created 08.10.2015
*******************************************************************************}
//49595300
unit umain;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils,  Forms, Controls, Graphics, Dialogs, DBGrids,
  Buttons, Menus, ActnList, XMLPropStorage, StdCtrls, Utils, uExtControls,
  uIntfStrConsts, db, memds, FileUtil, ipHTML, Translations, md5,
  ComCtrls, ExtCtrls, DbCtrls, Grids, uSystemMessage, uOrder,
  uBaseDbInterface,uBaseDbClasses,fautomationform;
type
  TfMain = class(TForm)
    acLogin: TAction;
    acLogout: TAction;
    acLoadOrder: TAction;
    acSearchMasterdata: TAction;
    acSearchOrder: TAction;
    acCloseOrder: TAction;
    ActionList1: TActionList;
    Bevel1: TBevel;
    Button1: TButton;
    cbVersion: TComboBox;
    eOrder: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    MainMenu: TMainMenu;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    miLanguage: TMenuItem;
    miMandant: TMenuItem;
    miOptions: TMenuItem;
    Panel1: TPanel;
    pAutomation: TPanel;
    Panel4: TPanel;
    Shape1: TShape;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    Splitter1: TSplitter;
    tvStep: TTreeView;
    procedure acCloseOrderExecute(Sender: TObject);
    procedure acLoadOrderExecute(Sender: TObject);
    procedure acLoginExecute(Sender: TObject);
    procedure acLogoutExecute(Sender: TObject);
    procedure acSearchMasterdataExecute(Sender: TObject);
    procedure DoRestoreConfig(Data: PtrInt);
    procedure eOrderKeyPress(Sender: TObject; var Key: char);
    procedure FAutomationSelectStep(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    function SetOrderfromSearch(aLink: string): Boolean;
    procedure tvStepSelectionChanged(Sender: TObject);
  private
    { private declarations }
    FOrder : TOrder;
    FAutomation : TFAutomation;
    procedure DoOpen;
  public
    { public declarations }
    procedure DoCreate;
  end;

var
  fMain: TfMain;
resourcestring
  strNoOrderFound                       = 'Es wurde kein Auftrag oder Artikel gefunden der zum Suchkriterium passt !';
  strCreateNewOrder                     = 'Neuer Auftrag';
  strNewOrderWillbeCreated              = 'Es wird ein %s für Artikel "%s" erstellt.';
implementation
{$R *.lfm}
uses uBaseApplication, uData,uMasterdata,uSearch,variants,uBaseERPDBClasses,
  uprometpythonscript,genpascalscript,Synautil,genscript;

procedure TfMain.DoCreate;
begin
  with Application as IBaseApplication do
    begin
      SetConfigName('Production');
    end;
  with Application as IBaseDbInterface do
    LoadMandants;
end;
procedure TfMain.acLoginExecute(Sender: TObject);
var
  a: TOrder;
begin
  Application.ProcessMessages;
  with Application as IBaseApplication do
    if not Login then
      begin
        Application.Terminate;
        exit;
      end;
  acLogin.Enabled:=False;
  acLogout.Enabled:=True;
  FOrder := TOrder.Create(nil);
end;
procedure TfMain.acLoadOrderExecute(Sender: TObject);
var
  aMasterdata: TMasterdata;
begin
  //Try to select by Orderno
  if not cbVersion.Enabled then //Wenn cbVersion Enabled ist ist es ein Artikel
    begin
      FOrder.SelectFromNumber('');
      FOrder.SelectFromCommission(eOrder.Text);
      FOrder.Open;
      if (FOrder.Count=0) and (IsNumeric(eOrder.Text)) then
        begin
          //Try to select by Commission
          FOrder.SelectFromNumber(eOrder.Text);
        end;
      FOrder.Open;
    end
  else FOrder.Close;
  if FOrder.Count<=0 then
    begin
      //Find Article and Create Order
      aMasterdata := TMasterdata.Create(nil);
      aMasterdata.SelectFromNumber(eOrder.Text);
      aMasterdata.Open;
      if cbVersion.Enabled and (cbVersion.Text<>'') then
        aMasterdata.Locate('VERSION',cbVersion.Text,[]);
      if aMasterdata.Count>0 then
        begin
          FOrder.OrderType.Open;
          if FOrder.OrderType.Locate('SI_PROD;TYPE',VarArrayOf(['Y',7]),[]) then
            begin
              if MessageDlg(strCreateNewOrder,Format(strNewOrderWillbeCreated,[FOrder.OrderType.FieldByName('STATUSNAME').AsString,aMasterdata.FieldByName('ID').AsString]),mtInformation,[mbOK,mbCancel],0) = mrOK then
                begin
                  FOrder.Insert;
                  FOrder.Positions.Insert;
                  //FOrder.Status.AsString:=FOrder.OrderType.FieldByName('STATUS').AsString;
                  FOrder.Positions.Assign(aMasterdata);
                  FOrder.Positions.Post;
                  FOrder.Post;
                  cbVersion.Enabled:=False;
                end
              else
                begin
                  eOrder.SelectAll;
                  eOrder.SetFocus;
                  exit;
                end;
            end;
        end;
      aMasterdata.Free;
    end;
  if FOrder.Count>0 then
    eOrder.Text:=FOrder.Number.AsString;
  if FOrder.Count<=0 then
    begin
      Showmessage(strNoOrderFound);
      eOrder.SelectAll;
      eOrder.SetFocus;
    end
  else DoOpen;
end;
procedure TfMain.acCloseOrderExecute(Sender: TObject);
begin
  fAutomation.Clear;
  tvStep.Items.Clear;
  eOrder.Enabled:=True;
  acSearchMasterdata.Enabled:=True;
  acSearchOrder.Enabled:=True;
  acLoadOrder.Enabled:=True;
  acCloseOrder.Enabled:=False;
  cbVersion.Enabled := False;
end;
procedure TfMain.acLogoutExecute(Sender: TObject);
begin
  with Application as IBaseApplication do
    Logout;
end;

procedure TfMain.acSearchMasterdataExecute(Sender: TObject);
begin
  fSearch.SetLanguage;
  fSearch.OnOpenItem:=@SetOrderfromSearch;
  fSearch.AllowSearchTypes(strOrders+','+strMasterdata);
  fSearch.Execute(True,'PRODSE','');
end;

procedure TfMain.DoRestoreConfig(Data: PtrInt);
begin
  with Application as IBaseApplication do
    RestoreConfig; //Must be called when Mainform is Visible
end;

procedure TfMain.eOrderKeyPress(Sender: TObject; var Key: char);
begin
  if Key=#13 then
    begin
      acLoadOrder.Execute;
    end
  else
    begin
      cbVersion.Text:='';
      cbVersion.Enabled := False;
    end;
end;

procedure TfMain.FAutomationSelectStep(Sender: TObject);
begin
  if (FAutomation.tvStep.Selected<>nil) and (tvStep.Items.Count>FAutomation.tvStep.Selected.AbsoluteIndex) then
    begin
      tvStep.Selected := tvStep.Items[FAutomation.tvStep.Selected.AbsoluteIndex];
      Shape1.Top:=tvStep.Top+tvStep.Selected.Top-((Shape1.Height-tvStep.Selected.Height) div 2);
    end;
end;

procedure TfMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  //FOrder.Free;
  with Application as IBaseApplication do
    begin
      Data.ActiveUsers.DataSet.AfterScroll:=nil;
      SaveConfig;
      DoExit;
    end;
end;

procedure TfMain.FormCreate(Sender: TObject);
begin
  FAutomation := TFAutomation.Create(Self);
  fautomationform.FAutomation := FAutomation;
  FAutomation.BorderStyle:=bsNone;
  FAutomation.Align:=alClient;
  FAutomation.Parent:=pAutomation;
  FAutomation.OnSelectStep:=@FAutomationSelectStep;
  FAutomation.Show;
  FAutomation.tvStep.Visible:=False;
end;

procedure TfMain.FormShow(Sender: TObject);
begin
  if not acLogin.Enabled then exit;
  acLogin.Execute;
  if Assigned(Data) then
    begin
      Application.QueueAsyncCall(@DoRestoreConfig,0);
    end;
end;

function TfMain.SetOrderfromSearch(aLink: string): Boolean;
var
  aMasterdata: TMasterdata;
begin
  aMasterdata := TMasterdata.Create(nil);
  aMasterdata.SelectFromLink(aLink);
  aMasterdata.Open;
  if aMasterdata.Count>0 then
    begin
      eOrder.Text:=aMasterdata.Number.AsString;
      cbVersion.Text:=aMasterdata.Version.AsString;
      aMasterdata.Select(aMasterdata.Number.AsString);
      aMasterdata.Open;
      cbVersion.Enabled:=aMasterdata.Count>1;
      cbVersion.Items.Clear;
      aMasterdata.First;
      while not aMasterdata.EOF do
        begin
          cbVersion.Items.Add(aMasterdata.Version.AsString);
          aMasterdata.Next;
        end;
    end;
  aMasterdata.Free;
end;

procedure TfMain.tvStepSelectionChanged(Sender: TObject);
begin
  if (tvStep.Selected<>nil) and (FAutomation.tvStep.Enabled) then
    FAutomation.tvStep.Selected := FAutomation.tvStep.Items[tvStep.Selected.AbsoluteIndex];
end;

procedure TfMain.DoOpen;
begin
  eOrder.Enabled:=FOrder.Count>0;
  eOrder.Text:=FOrder.Number.AsString;
  FreeAndNil(FOrder);
  FOrder := TOrder.Create(nil);
  cbVersion.Enabled:=cbVersion.Enabled and (FOrder.Count>0);
  tvStep.Enabled:=FOrder.Count>0;
  tvStep.Items.Clear;
  FOrder.SelectFromNumber(eOrder.Text);
  FOrder.Open;
  if FOrder.Count>0 then
    begin
      FOrder.Positions.Close;
      FOrder.Positions.Open;
      FOrder.Positions.First;
      FAutomation.DataSet := FOrder.Positions;
      FAutomation.DoOpen;
    end;
  tvStep.Items.Assign(FAutomation.tvStep.Items);
  FAutomationSelectStep(FAutomation.tvStep);

  eOrder.Enabled:=False;
  cbVersion.Enabled:=False;
  acSearchMasterdata.Enabled:=False;
  acSearchOrder.Enabled:=False;
  acLoadOrder.Enabled:=False;
  acCloseOrder.Enabled:=True;
  tvStep.Enabled:=True;
end;

procedure InternalSleep(MiliSecValue: LongInt); StdCall;
var
  aTime: Int64;
begin
  aTime := GetTicks;
  while (GetTicks-aTime) < MiliSecValue do
    Application.ProcessMessages;
end;

initialization
  genpascalscript.DoSleep:=@InternalSleep;
end.
