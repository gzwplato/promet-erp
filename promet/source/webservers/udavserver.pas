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
*******************************************************************************}
unit udavserver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,uhttpserver, dom, xmlread, xmlwrite,syncobjs,Sockets;

type
  TDAVFile = class;

  { TDAVDirectoryList }

  TDAVDirectoryList = class(TList)
  private
    function Get(Index: Integer): TDAVFile;
    procedure Put(Index: Integer; AValue: TDAVFile);
  public
    constructor Create;
    function HasPath(aPath : string) : Boolean;
    property Files[Index: Integer]: TDAVFile read Get write Put; default;
    destructor Destroy;override;
  end;

  { TDAVFile }

  TDAVFile = class(TDAVDirectoryList)
  private
    FASet: TStringList;
    FCHS: string;
    FIsCal: Boolean;
    FIsCalU: Boolean;
    FIsDir: Boolean;
    FIsTodo: Boolean;
    FLUserURI: string;
    FName: string;
    FPath: string;
    FProperties: TStringList;
    FUserURI: string;
    procedure SetName(AValue: string);
  public
    constructor Create(aName : string;aIsDir : Boolean = False);
    destructor Destroy;override;
    property Name : string read FName write SetName;
    property Properties : TStringList read FProperties;
    property IsDir : Boolean read FIsDir;
    property IsCalendar : Boolean read FIsCal write FIsCal;
    property IsCalendarUser : Boolean read FIsCalU write FIsCalU;
    property IsTodoList : Boolean read FIsTodo write FIsTodo;
    property CalendarHomeSet : string read FCHS write FCHS;
    property CurrentUserPrincipal : string read FUserURI write FUserURI;
    property CurrentUser : string read FLUserURI write FLUserURI;
    property UserAdressSet : TStringList read FASet;
    property Path : string read FPath write FPath;
  end;

  { TDAVSocket }

  TDAVSocket = class(TTCPHttpThrd)
  private
    FStatus: Integer;
    FURI: string;
    FHeadersOut : TStringList;
    FUser: string;
  public
    constructor Create(hsock: tSocket);override;
    property URI : string read FURI;
    property Status : Integer read FStatus write FStatus;
    property HeaderOut : TStringList read FHeadersOut write FHeadersOut;
    function ProcessHttpRequest(Request, aURI: string): integer; override;
    function CheckAuth: Boolean;
    property User : string read FUser write FUser;
  end;

  TDAVGetDirectoryList = function(aSocket : TDAVSocket;aDir : string;a3 : Integer;var aDirList : TDAVDirectoryList) : Boolean of object;
  TDAVGetCTag = function(aSocket : TDAVSocket;aDir : string;var aCTag : Int64) : Boolean of object;
  TDAVFileEvent = function(aSocket : TDAVSocket;aDir : string) : Boolean of object;
  TDAVFileStreamEvent = function(aSocket : TDAVSocket;aDir : string;Stream : TStream;var eTag : string;var Result : Integer) : Boolean of object;
  TDAVFileStreamDateEvent = function(aSocket : TDAVSocket;aDir : string;Stream : TStream;var FLastModified : TDateTime;var MimeType : string;var eTag : string) : Boolean of object;
  TDAVLoginEvent = function(aSocket : TDAVSocket;aUser,aPassword : string) : Boolean of object;
  TDAVAccessEvent = procedure(aSocket : TDAVSocket;Info : string) of object;

  { TWebDAVServer }

  TWebDAVServer = class(TTCPHttpDaemon)
  private
    FAccess: TDAVAccessEvent;
    FCtag: TDAVGetCTag;
    FDelete: TDAVFileEvent;
    FGet: TDAVFileStreamDateEvent;
    FGetDirList: TDAVGetDirectoryList;
    FMkCol: TDAVFileEvent;
    FPost: TDAVFileStreamEvent;
    FPut: TDAVFileStreamEvent;
    FreadAllowed: TDAVFileEvent;
    FUserLogin: TDAVLoginEvent;
    FWriteAllowed: TDAVFileEvent;
    FCS : TCriticalSection;
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Lock;
    procedure Unlock;
    procedure InternalMessage(aMsg: string); override;
    property OnGetDirectoryList : TDAVGetDirectoryList read FGetDirList write FGetDirList;
    property OnMkCol : TDAVFileEvent read FMkCol write FMkCol;
    property OnDelete : TDAVFileEvent read FDelete write FDelete;
    property OnPutFile : TDAVFileStreamEvent read FPut write FPut;
    property OnPostFile : TDAVFileStreamEvent read FPost write FPost;
    property OnGetFile : TDAVFileStreamDateEvent read FGet write FGet;
    property OnReadAllowed : TDAVFileEvent read FreadAllowed write FReadAllowed;
    property OnWriteAllowed : TDAVFileEvent read FWriteAllowed write FWriteAllowed;
    property OnUserLogin : TDAVLoginEvent read FUserLogin write FUserLogin;
    property OngetCTag : TDAVGetCTag read FCtag write FCtag;
    property OnAccess : TDAVAccessEvent read FAccess write FAccess;
  end;

  { TStreamOutput }

  TStreamOutput = class
  private
    Foutput: TStream;
  protected
    FSocket: TDAVSocket;
    procedure DoneInput;virtual;abstract;
    function  HandleInput(ABuffer: pchar; ASize: integer): integer; virtual;abstract;
  public
    constructor Create(ASocket: TDAVSocket;aIn,aOut : TMemoryStream);virtual;
    property Output : TStream read Foutput write FOutput;
  end;
  TMemoryStreamOutput = class(TStreamOutput)
  end;

  { TXmlOutput }

  TXmlOutput = class(TMemoryStreamOutput)
  private
    FIn: TMemoryStream;
    FOut : TMemoryStream;
    ADoc: TXMLDocument;
    aNotFoundProp : TStrings;
    aPropNode: TDOMElement;
    aMSRes: TDOMElement;
    aDepth: Integer;
    Path : AnsiString;
    aNs : string;
    aPrefix : string;
  protected
    procedure DoneInput; override;
    function FindProp(aprop: string): Integer;
    procedure RemoveProp(aProp: string);
    function BuildStatus(aStatus: Integer; Statusname: string): string;
    function HandleXMLRequest(aDocument : TXMLDocument) : Boolean;virtual;
    function FindDefaultPrefix(aDocument: TXMLDocument) : Boolean;
  public
    constructor Create(ASocket: TDAVSocket;aIn,aOut : TMemoryStream);override;
    destructor Destroy; override;
  end;
  TFileStreamInput = class(TStreamOutput)
  private
    FEvent: TDAVFileStreamEvent;
  protected
    procedure DoneInput; override;
  public
    property Event : TDAVFileStreamEvent read FEvent write FEvent;
  end;
  TFileStreamOutput = class(TStreamOutput)
  private
    FEvent: TDAVFileStreamDateEvent;
  protected
    procedure DoneInput; override;
  public
    constructor Create(ASocket: TDAVSocket; aIn, aOut: TMemoryStream); override;
    property Event : TDAVFileStreamDateEvent read FEvent write FEvent;
  end;
  TMultistatusXmlOutput = class(TXmlOutput)
  protected
    aProperties: TStringList;
    function HandleXMLRequest(aDocument: TXMLDocument): Boolean; override;
    function ImportNamespaces(aDocument: TXMLDocument): Boolean;
  public
    constructor Create(ASocket: TDAVSocket; aIn, aOut: TMemoryStream); override;
    destructor Destroy; override;
  end;
  TDAVOptionsOutput = class(TXmlOutput)
  private
    FDir : string;
    FDepth : Integer;
    FDirList : TDAVDirectoryList;
    FResult : Boolean;
  protected
    function DoGetDirectoryList(aDir : string;a3 : Integer;var aDirList : TDAVDirectoryList) : Boolean;
    function HandleXMLRequest(aDocument : TXMLDocument) : Boolean;override;
  end;
  TDAVFindPropOutput = class(TMultistatusXmlOutput)
  private
    FDir : string;
    FDepth : Integer;
    FDirList : TDAVDirectoryList;
    FResult : Boolean;
  protected
    function DoGetDirectoryList(aDir : string;a3 : Integer;var aDirList : TDAVDirectoryList) : Boolean;
    function HandleXMLRequest(aDocument : TXMLDocument) : Boolean;override;
  end;
  TDAVMkColOutput = class(TXmlOutput)
  protected
    function HandleXMLRequest(aDocument : TXMLDocument) : Boolean;override;
  end;
  TDAVDeleteOutput = class(TXmlOutput)
  protected
    function HandleXMLRequest(aDocument : TXMLDocument) : Boolean;override;
  end;
  TDAVReportOutput = class(TMultistatusXmlOutput)
  protected
    function HandleXMLRequest(aDocument : TXMLDocument) : Boolean;override;
  end;

implementation

uses base64,Utils,uhttputil,uBaseApplication;

function InternURLEncode(aURL : string) : string;
begin
  Result := StringReplace(Utils.HTTPEncode(aURL),'%2f','/',[rfReplaceAll,rfIgnoreCase])
end;

{ TMultistatusXmlOutput }

function TMultistatusXmlOutput.HandleXMLRequest(aDocument: TXMLDocument
  ): Boolean;
var
  a, i: Integer;
  Attr, aChildNode: TDOMNode;
  aAttrPrefix, aLocalName, tmp1: String;
  aNSName, tmp: DOMString;
  Attr1: TDOMAttr;
begin
  Result:=inherited HandleXMLRequest(aDocument);
end;

function TMultistatusXmlOutput.ImportNamespaces(aDocument: TXMLDocument): Boolean;
var
  a: Integer;
  Attr: TDOMNode;
  aAttrPrefix, aLocalName: String;
  aNSName, tmp: DOMString;
  Attr1: TDOMAttr;
begin
  tmp := aDocument.DocumentElement.NodeName;
  if trim(copy(tmp,0,pos(':',tmp)-1)) <> '' then
    aPrefix := trim(copy(aDocument.DocumentElement.NodeName,0,pos(':',aDocument.DocumentElement.NodeName)-1));
  for a := 0 to aDocument.DocumentElement.Attributes.Length-1 do
    begin
      Attr := aDocument.DocumentElement.Attributes[a];
      aAttrPrefix := copy(Attr.NodeName,0,pos(':',Attr.NodeName)-1);
      aLocalName := copy(Attr.NodeName,pos(':',Attr.NodeName)+1,length(Attr.NodeName));
      aNSName := Attr.NodeValue;
      if (aAttrPrefix = 'xmlns') and (aLocalName<>'') then
        begin
          Attr1 := aDocument.DocumentElement.OwnerDocument.CreateAttribute('xmlns:'+aLocalName);
          Attr1.NodeValue:=aNSName;
          aMSRes.Attributes.setNamedItem(Attr1);
          if BaseApplication.HasOption('debug') then
            writeln('Old NS:'+aLocalName+'='+aNSName);
          if aNSName=aNs then
            begin
              aPrefix:=aLocalName;
            end;
        end
      else if (aLocalName = 'xmlns') and (aNSName<>'') then
        begin
          Attr1 := aDocument.DocumentElement.OwnerDocument.CreateAttribute('xmlns:'+aPrefix);
          Attr1.NodeValue:=aNSName;
          aMSRes.Attributes.setNamedItem(Attr1);
          if BaseApplication.HasOption('debug') then
            writeln('Old NS:'+aNSName+'=');
        end;

    end;
end;

function TXmlOutput.FindDefaultPrefix(aDocument: TXMLDocument
  ): Boolean;
var
  tmp, aNSName: DOMString;
  a: Integer;
  Attr: TDOMNode;
  aLocalName, aAttrPrefix: String;
  Attr1: TDOMAttr;
begin
  Result := False;
  if not Assigned(aDocument.DocumentElement) then exit;
  tmp := aDocument.DocumentElement.NodeName;
  if trim(copy(tmp,0,pos(':',tmp)-1)) <> '' then
    begin
      aPrefix := trim(copy(aDocument.DocumentElement.NodeName,0,pos(':',aDocument.DocumentElement.NodeName)-1));
      Result := True;
    end;
  for a := 0 to aDocument.DocumentElement.Attributes.Length-1 do
    begin
      Attr := aDocument.DocumentElement.Attributes[a];
      aAttrPrefix := copy(Attr.NodeName,0,pos(':',Attr.NodeName)-1);
      aLocalName := copy(Attr.NodeName,pos(':',Attr.NodeName)+1,length(Attr.NodeName));
      aNSName := Attr.NodeValue;
      if (aAttrPrefix = 'xmlns') and (aLocalName<>'') then
        begin
          Attr1 := aDocument.DocumentElement.OwnerDocument.CreateAttribute('xmlns:'+aLocalName);
          Attr1.NodeValue:=aNSName;
          if aNSName=aNs then
            begin
              aPrefix:=aLocalName;
              Result := True;
            end;
        end;
    end;
end;

constructor TMultistatusXmlOutput.Create(ASocket: TDAVSocket; aIn,
  aOut: TMemoryStream);
begin
  inherited Create(ASocket, aIn, aOut);
  aProperties := TStringList.Create;
end;

destructor TMultistatusXmlOutput.Destroy;
begin
  aProperties.Free;
  inherited Destroy;
end;

{ TFileStreamOutput }

procedure TFileStreamOutput.DoneInput;
var
  FeTag : string;
  FStatus : Integer;
  FModified : TDateTime;
  FMimeType : string;
begin
  TDAVSocket(FSocket).Status := 500;
  TWebDAVServer(TDAVSocket(FSocket).Creator).Lock;
  if Assigned(Event) then
    if Event(TDAVSocket(FSocket),HTTPDecode(TDAVSocket(FSocket).URI),Foutput,FModified,FMimeType,FeTag) then
      begin
        TDAVSocket(FSocket).Status := 200;
        //TDAVSocket(FSocket).HeaderOut.Add('Last-Modified: '+ LocalTimeToGMT(FModified));
      end;
  TWebDAVServer(TDAVSocket(FSocket).Creator).Unlock;
end;

constructor TFileStreamOutput.Create(ASocket: TDAVSocket; aIn,
  aOut: TMemoryStream);
begin
  inherited Create(ASocket, aIn, aOut);
  Foutput := aOut;
end;

{ TFileStreamInput }

procedure TFileStreamInput.DoneInput;
var
  FeTag : string;
  FStatus : Integer;
begin
  TDAVSocket(FSocket).Status := 500;
  TWebDAVServer(TDAVSocket(FSocket).Creator).Lock;
  if BaseApplication.HasOption('debug') then
    writeln('<'+MemoryStreamToString(TDAVSocket(FSocket).InputData));
  if Assigned(Event) then
    if Event(TDAVSocket(FSocket),HTTPDecode(TDAVSocket(FSocket).URI),TDAVSocket(FSocket).InputData,FeTag,FStatus) then
      TDAVSocket(FSocket).Status:=FStatus;
  TWebDAVServer(TDAVSocket(FSocket).Creator).Unlock;
end;

{ TStreamOutput }

function TDAVSocket.CheckAuth: Boolean;
var
  aUser: String;
begin
  if Parameters.Values['authorization'] <> '' then
    begin
      aUser := Parameters.Values['authorization'];
      aUser := DecodeStringBase64(copy(aUser,pos(' ',aUser)+1,length(aUser)));
      TWebDAVServer(Creator).Lock;
      if Assigned(TWebDAVServer(Creator).OnUserLogin) then
        TWebDAVServer(Creator).OnUserLogin(TDAVSocket(Self),copy(aUser,0,pos(':',aUser)-1),copy(aUser,pos(':',aUser)+1,length(aUser)));
      TWebDAVServer(Creator).Unlock;
    end;
end;

constructor TStreamOutput.Create(ASocket: TDAVSocket; aIn, aOut: TMemoryStream);
begin
  FSocket := ASocket;
end;

function TDAVOptionsOutput.DoGetDirectoryList(aDir: string; a3: Integer;
  var aDirList: TDAVDirectoryList): Boolean;
begin
  FDir := aDir;
  FDepth:=a3;
  FDirList:=aDirList;
  if Assigned(TWebDAVServer(FSocket.Creator).OnGetDirectoryList) then
    FResult := TWebDAVServer(FSocket.Creator).OnGetDirectoryList(TDAVSocket(FSocket),FDir,FDepth,FDirList);
  aDirList:=FDirList;
  Result := FResult;
end;

function TDAVOptionsOutput.HandleXMLRequest(aDocument: TXMLDocument): Boolean;
var
  aOptionsRes: TDOMElement;
  tmp: DOMString = 'D:options';
  aActivityCollection: TDOMElement = nil;
  aHref: TDOMElement;
  aDirList : TDAVDirectoryList;
  AuthReq: Boolean;
begin
  Result := Inherited HandleXMLRequest(aDocument);
  FindDefaultPrefix(aDocument);
  aOptionsRes := aDocument.CreateElementNS('DAV:',aPrefix+':options-response');
  if Assigned(aDocument.DocumentElement) then
    aActivityCollection := TDOMElement(aDocument.DocumentElement.FirstChild);
  if not Assigned(aActivityCollection) then
    aActivityCollection := aDocument.CreateElement(aPrefix+':activity-collection-set');
  aOptionsRes.AppendChild(aActivityCollection);
  aHref := aDocument.CreateElement(aPrefix+':href');
  if copy(Path,0,1) <> '/' then Path := '/'+Path;
  if pos('trunk',Path) > 0 then
    Path := StringReplace(Path,'trunk','!svn/act',[]);
  aDepth := StrToIntDef(trim(FSocket.Parameters.Values['depth']),0);
  aDirList := TDAVDirectoryList.Create;
  TWebDAVServer(FSocket.Creator).Lock;
  Result := DoGetDirectoryList(Path,aDepth,aDirList);
  TWebDAVServer(FSocket.Creator).Unlock;
  aDirList.Free;

  aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(Path)));
  aActivityCollection.AppendChild(aHref);
  if Assigned(aDocument.DocumentElement) then
    aDocument.DocumentElement.Free;
  aDocument.AppendChild(aOptionsRes);
  FSocket.Status:=200;
  TWebDAVServer(FSocket.Creator).Lock;
  if Assigned(TWebDAVServer(FSocket.Creator).OnReadAllowed) and (not TWebDAVServer(FSocket.Creator).OnReadAllowed(TDAVSocket(FSocket),Path)) then
    begin
      FSocket.Status:=401;
      TDAVSocket(FSocket).HeaderOut.Add('WWW-Authenticate: Basic realm="Promet-ERP"');
      Result := True;
    end;
  TWebDAVServer(FSocket.Creator).Unlock;
end;

{ TDAVSocket }

constructor TDAVSocket.Create(hsock: tSocket);
begin
  inherited Create(hsock);
  FUser:='';
end;

function TDAVSocket.ProcessHttpRequest(Request, aURI: string): integer;
var
  Res : TStreamOutput = nil;

  procedure AddDAVheaders;
  begin
    HeaderOut.Add('DAV: 1,2, access-control, calendar-access');
    HeaderOut.Add('DAV: <http://apache.org/dav/propset/fs/1>');
    HeaderOut.Add('MS-Author-Via: DAV');
    HeaderOut.Add('Vary: Accept-Encoding');
  end;

begin
  if Assigned(TWebDAVServer(Creator).OnAccess) then
    TWebDAVServer(Creator).OnAccess(Self,'<'+Request+' '+aURI);
  FURI:=aURI;
  HeaderOut := TStringList.Create;
  HeaderOut.Add('Content-type: text/xml');
  HeaderOut.Add('Content-Charset: utf8');
  try
    Result := 500;
    case Request of
    'OPTIONS':
       begin
         AddDAVheaders;
         HeaderOut.Add('DAV: version-control,checkout,working-resource');
         HeaderOut.Add('DAV: 1, calendar-access, calendar-schedule, calendar-proxy');
         HeaderOut.Add('allow: GET, HEAD, POST, OPTIONS, MKCOL, DELETE, PUT, LOCK, UNLOCK, COPY, MOVE, PROPFIND, SEARCH, REPORT, MKCALENDAR, ACL');
         Res := TDAVOptionsOutput.Create(Self,InputData,OutputData);
       end;
    'REPORT':
       begin
         AddDAVheaders;
         HeaderOut.Add('DAV: version-control,checkout,working-resource');
         HeaderOut.Add('allow: GET, HEAD, POST, OPTIONS, MKCOL, DELETE, PUT, LOCK, UNLOCK, COPY, MOVE, PROPFIND, SEARCH, REPORT, MKCALENDAR, ACL');
         Res := TDAVReportOutput.Create(Self,InputData,OutputData);
       end;
    'PROPFIND':
       begin
         AddDAVheaders;
         Res := TDAVFindPropOutput.Create(Self,InputData,OutputData);
       end;
    'GET','HEAD':
       begin
         CheckAuth;
         TWebDAVServer(Creator).Lock;
         if Assigned(TWebDAVServer(Creator).OnReadAllowed)
         and (not TWebDAVServer(Creator).OnReadAllowed(Self,HTTPDecode(URI))) then
           begin
             Status:=401;
             HeaderOut.Add('WWW-Authenticate: Basic realm="Promet-ERP"');
           end
         else
           begin
             Res := TFileStreamOutput.Create(Self,InputData,OutputData);
             TFileStreamOutput(Res).Event:=TWebDAVServer(Creator).FGet;
           end;
         TWebDAVServer(Creator).Unlock;
       end;
    'PUT':
       begin
         CheckAuth;
         TWebDAVServer(Creator).Lock;
         if Assigned(TWebDAVServer(Creator).OnReadAllowed)
         and (not TWebDAVServer(Creator).OnReadAllowed(Self,HTTPDecode(URI))) then
           begin
             Status:=401;
             HeaderOut.Add('WWW-Authenticate: Basic realm="Promet-ERP"');
           end
         else
           begin
             Res := TFileStreamInput.Create(Self,InputData,OutputData);
             TFileStreamInput(Res).Event:=TWebDAVServer(Creator).FPut;
           end;
         TWebDAVServer(Creator).Unlock;
       end;
    'POST':
       begin
         CheckAuth;
         TWebDAVServer(Creator).Lock;
         if Assigned(TWebDAVServer(Creator).OnReadAllowed)
         and (not TWebDAVServer(Creator).OnReadAllowed(Self,HTTPDecode(URI))) then
           begin
             Status:=401;
             HeaderOut.Add('WWW-Authenticate: Basic realm="Promet-ERP"');
           end
         else
           begin
             Res := TFileStreamInput.Create(Self,InputData,OutputData);
             TFileStreamInput(Res).Event:=TWebDAVServer(Creator).FPost;
           end;
         TWebDAVServer(Creator).Unlock;
       end;
    'MKCOL':
       begin
         CheckAuth;
         AddDAVheaders;
         Res := TDAVMkColOutput.Create(Self,InputData,OutputData);
       end;
    'DELETE':
       begin
         CheckAuth;
         AddDAVheaders;
         Res := TDAVDeleteOutput.Create(Self,InputData,OutputData);
       end;
    end;
    if Assigned(Res) then
      begin
        Res.DoneInput;
        if Status<>0 then
          Result := Status;
        Headers.Clear;
        Headers.AddStrings(HeaderOut);
        if Assigned(TWebDAVServer(Creator).OnAccess) then
          TWebDAVServer(Creator).OnAccess(Self,'>'+IntToStr(Result));
      end
    else
      begin
        Headers.Clear;
        Headers.AddStrings(HeaderOut);
        if Status<>0 then
          Result := Status;
        if Assigned(TWebDAVServer(Creator).OnAccess) then
          TWebDAVServer(Creator).OnAccess(Self,'>'+IntToStr(Result));
      end;
  finally
    HeaderOut.Free;
  end;
end;

{ TWebDAVServer }

constructor TWebDAVServer.Create;
begin
  inherited Create;
  ThreadType:=TDAVSocket;
  FCS := TCriticalSection.Create;
end;

destructor TWebDAVServer.Destroy;
begin
  FCS.Destroy;
  inherited Destroy;
end;

procedure TWebDAVServer.Lock;
begin
  FCS.Enter;
end;

procedure TWebDAVServer.Unlock;
begin
  FCS.Leave;
end;

procedure TWebDAVServer.InternalMessage(aMsg: string);
begin
  if Assigned(OnAccess) then
    OnAccess(nil,'!'+aMsg);
end;

{ TDAVDirectoryList }

function TDAVDirectoryList.Get(Index: Integer): TDAVFile;
begin
  Result := TDAVFile(Items[Index]);
end;

procedure TDAVDirectoryList.Put(Index: Integer; AValue: TDAVFile);
begin
  Items[Index] := Pointer(AValue);
end;

constructor TDAVDirectoryList.Create;
begin
  inherited;
end;

function TDAVDirectoryList.HasPath(aPath: string): Boolean;
var
  i: Integer;
  tmp: String;
begin
  Result:=False;
  if pos(#0,aPath)>0 then
    aPath := copy(aPath,0,pos(#0,aPath)-1);
  if copy(aPath,length(aPath),1)='/' then
    aPath := copy(aPath,0,length(aPath)-1);
  for i := 0 to Count-1 do
    begin
      tmp := Files[i].Path;
      tmp += Files[i].Name;
      if copy(tmp,length(tmp),1)='/' then
        tmp := copy(tmp,0,length(tmp)-1);
      if tmp=aPath then
        begin
          Result := True;
          break;
        end;
    end;
end;

destructor TDAVDirectoryList.Destroy;
begin
  inherited Destroy;
end;

{ TDAVFile }

procedure TDAVFile.SetName(AValue: string);
begin
  if FName=AValue then Exit;
  FName:=AValue;
end;

constructor TDAVFile.Create(aName: string; aIsDir: Boolean);
begin
  inherited Create;
  FName := ExtractFileName(aName);
  FIsDir := aIsDir;
  FIsCal:=False;
  FIsTodo:=False;
  FProperties := TStringList.Create;
  FASet := TStringList.Create;
  FPath := ExtractFilePath(aName);
end;

destructor TDAVFile.Destroy;
begin
  FASet.Free;
  FProperties.Free;
  inherited Destroy;
end;

constructor TXmlOutput.Create(ASocket: TDAVSocket; aIn, aOut: TMemoryStream);
begin
  ADoc := TXMLDocument.Create;
  FIn := aIn;
  FOut := aOut;
  aNotFoundProp := TStringList.Create;
  aNS := 'DAV:';
  aPrefix:='D';
  inherited Create(ASocket,aIn,aOut);
end;
function TXmlOutput.FindProp(aprop : string) : Integer;
var
  b : Integer;
begin
  b := 0;
  while b < aNotFoundProp.Count do
    begin
      if pos(lowercase(aProp),lowercase(aNotFoundProp.Names[b])) > 0 then
        begin
          Result := b;
          exit;
        end
      else inc(b);
    end;
  Result := -1;
end;
procedure TXmlOutput.RemoveProp(aProp : string);
var
  b : Integer;
begin
  b := 0;
  while b < aNotFoundProp.Count do
    begin
      if pos(lowercase(aProp),lowercase(aNotFoundProp.Names[b])) > 0 then
        aNotFoundProp.Delete(b)
      else inc(b);
    end;
end;
procedure TXmlOutput.DoneInput;
var
  tmp: String;
begin
  FIn.Position:=0;
  if BaseApplication.HasOption('debug') then
    begin
      writeln('<'+TDAVSocket(FSocket).Parameters.Text);
      writeln('<'+MemoryStreamToString(Fin));
    end;
  try
    if Fin.Size>0 then
      ReadXMLFile(ADoc,FIn);
  except
    on e : Exception do
      begin
        TDAVSocket(FSocket).Status:=424;
        exit;
      end;
  end;
  FOut.Clear;
  if HandleXMLRequest(ADoc) then
    begin
      WriteXML(ADoc,FOut);
      //Self.FBufferSize := FOut.Size;
      FOut.Position:=0;
      TDAVSocket(FSocket).HeaderOut.Add('ContentLength: '+IntToStr(FOut.Size));
      TDAVSocket(FSocket).OutputData := Self.FOut;
    end
  else
    begin
      TDAVSocket(FSocket).HeaderOut.Add('ContentLength: 0');
      TDAVSocket(FSocket).Status:=403;
      FOut.Clear;
      TDAVSocket(FSocket).OutputData := Self.FOut;
    end;
  if BaseApplication.HasOption('debug') then
    begin
      writeln('>'+MemoryStreamToString(FOut));
    end;
end;
function TXmlOutput.BuildStatus(aStatus: Integer;Statusname : string): string;
begin
  Result := 'HTTP/1.1 '+IntToStr(aStatus)+' '+StatusName;
end;

function TXmlOutput.HandleXMLRequest(aDocument: TXMLDocument): Boolean;
begin
  Result := False;
  Path := TDAVSocket(FSocket).URI;
  TDAVSocket(FSocket).CheckAuth;
end;

destructor TXmlOutput.Destroy;
begin
  FIn.Free;
  FOut.Free;
  aNotFoundProp.Free;
  inherited Destroy;
end;

function TDAVFindPropOutput.DoGetDirectoryList(aDir: string; a3: Integer;
  var aDirList: TDAVDirectoryList): Boolean;
begin
  FDir := aDir;
  FDepth:=a3;
  FDirList := aDirList;
  if Assigned(TWebDAVServer(FSocket.Creator).OnGetDirectoryList) then
    FResult := TWebDAVServer(FSocket.Creator).OnGetDirectoryList(TDAVSocket(FSocket),FDir,FDepth,FDirList);
  aDirList:=FDirList;
  Result := FResult;
end;

function TDAVFindPropOutput.HandleXMLRequest(aDocument: TXMLDocument): Boolean;
var
  tmp: DOMString;
  aDirList : TDAVDirectoryList = nil;
  i: Integer;
  pfNode: TDOMElement;
  tmp1: DOMString;
  a: Integer;
  Attr, aChildNode: TDOMNode;
  aAttrPrefix: String;
  aLocalName,aNSName: String;
  Attr1: TDOMAttr;
  tmp2: DOMString;

  function AddNS(anPrefix,aNS : string) : string;
  var
    a : Integer;
    aFound: Boolean;
  begin
    aFound:=False;
    for a := 0 to aDocument.DocumentElement.Attributes.Length-1 do
      begin
        Attr := aDocument.DocumentElement.Attributes[a];
        aAttrPrefix := copy(Attr.NodeName,0,pos(':',Attr.NodeName)-1);
        aLocalName := copy(Attr.NodeName,pos(':',Attr.NodeName)+1,length(Attr.NodeName));
        aNSName := Attr.NodeValue;
        if (aAttrPrefix = 'xmlns') and (aNSName=aNS) then
          begin
            aFound:=True;
            Result := aLocalName;
            exit;
          end;
      end;
    if not aFound then
      begin
        Attr := TDomElement(aDocument.DocumentElement).OwnerDocument.CreateAttribute('xmlns:'+anPrefix);
        Attr.NodeValue:=aNS;
        aDocument.DocumentElement.Attributes.setNamedItem(Attr);
        Result := anPrefix;
        if BaseApplication.HasOption('debug') then
          writeln('New NS:'+anPrefix+'='+aNS);
      end;
  end;
  procedure CreateResponse(aPath : string;aParent : TDOMElement;Properties : TStrings;ns : string = 'DAV:';prefix : string = 'D';aFile : TDAVFile = nil);
  var
    aResponse: TDOMElement;
    aHref: TDOMElement;
    aPropStat: TDOMElement;
    aStatus: TDOMElement;
    aPropC: TDOMElement;
    aProp: TDOMElement;
    a: Integer;
    aLock: TDOMElement;
    aLockEntry: TDOMElement;
    aPropD: TDOMNode;
    aPropE: TDOMNode;
    aPropF: TDOMNode;
    b: Integer;
    aPropG: TDOMNode;
    bPrefix : string;
    FcTag: String = '';
    aTextNode: TDOMText;
  begin
    if Assigned(aFile) then FcTag:=aFile.Properties.Values['getctag'];
    if Assigned(TWebDAVServer(FSocket.Creator).OnAccess) then
      TWebDAVServer(FSocket.Creator).OnAccess(FSocket,'>'+aPath+' '+prefix+' '+FcTag);
    aNotFoundProp.Assign(Properties);
    aResponse := aDocument.CreateElement(prefix+':response');
    aParent.AppendChild(aResponse);
    aHref := aDocument.CreateElement(prefix+':href');
    RemoveProp(':href');
    aResponse.AppendChild(aHref);
    if not (Assigned(aFile) and (not aFile.IsDir)) then
      if copy(aPath,length(aPath),1) <> '/' then aPath := aPath+'/';
    aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aPath)));
    aPropStat := aDocument.CreateElement(prefix+':propstat');
    aResponse.AppendChild(aPropStat);
    aProp := aDocument.CreateElement(prefix+':'+'prop');
    aPropStat.AppendChild(aProp);
    if Assigned(aFile) then
      begin
        aPropC := nil;
        if (FindProp(':resourcetype') > -1)  then
          begin
            tmp := aNotFoundProp.ValueFromIndex[FindProp(':resourcetype')];
            if pos(':',tmp)=0 then tmp := prefix+':'+tmp;
            aPropC := aDocument.CreateElement(tmp);
            RemoveProp(prefix+':resourcetype');
            aProp.AppendChild(aPropC);
          end;
        if aFile.CurrentUserPrincipal<>'' then
          begin
            if (FindProp(':current-user-principal') > -1) then
              begin
                tmp := aNotFoundProp.ValueFromIndex[FindProp(':current-user-principal')];
                if pos(':',tmp)=0 then tmp := prefix+':'+tmp;
                aPropD := aDocument.CreateElement(tmp);
                aProp.AppendChild(apropD);
                aHref := aDocument.CreateElement(prefix+':href');
                aPropD.AppendChild(aHref);
                aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aFile.CurrentUserPrincipal)));
                RemoveProp(':current-user-principal');
              end;
          end;
        if (FindProp(':calendar-user-address-set') > -1)  then
          begin
            aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':calendar-user-address-set')]);
            aProp.AppendChild(apropD);
            aHref := aDocument.CreateElement(prefix+':href');
            aPropD.AppendChild(aHref);
            aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aPath+'user/')));
            RemoveProp(':calendar-user-address-set');
          end;
        if (FindProp(':calendar-home-set') > -1) then
          begin
            tmp := aNotFoundProp.ValueFromIndex[FindProp(':calendar-home-set')];
            AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
            aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':calendar-home-set')]);
            aProp.AppendChild(apropD);
            aHref := aDocument.CreateElement(prefix+':href');
            aPropD.AppendChild(aHref);
            aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aFile.CalendarHomeSet)));
            RemoveProp(':calendar-home-set');
          end;
        if (FindProp(':owner') > -1)  then
          begin
            aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':owner')]);
            aProp.AppendChild(apropD);
            aHref := aDocument.CreateElement(prefix+':href');
            aPropD.AppendChild(aHref);
            aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aFile.CurrentUser)));
            RemoveProp(':owner');
          end;
        if FindProp(':schedule-inbox-URL') > -1  then
          begin
            tmp := aNotFoundProp.ValueFromIndex[FindProp(':schedule-inbox-URL')];
            AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
            aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':schedule-inbox-URL')]);
            aProp.AppendChild(apropD);
            aHref := aDocument.CreateElement(prefix+':href');
            aPropD.AppendChild(aHref);
            aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aFile.CalendarHomeSet+'home/')));
            RemoveProp(':schedule-inbox-URL');
          end;
        if FindProp(':schedule-outbox-URL') > -1  then
          begin
            tmp := aNotFoundProp.ValueFromIndex[FindProp(':schedule-outbox-URL')];
            AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
            aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':schedule-outbox-URL')]);
            aProp.AppendChild(apropD);
            aHref := aDocument.CreateElement(prefix+':href');
            aPropD.AppendChild(aHref);
            aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aFile.CalendarHomeSet+'home/')));
            RemoveProp(':schedule-outbox-URL');
          end;
        if (aFile.UserAdressSet.Count>0) and (FindProp(':calendar-user-address-set') > -1) then
          begin
            tmp := aNotFoundProp.ValueFromIndex[FindProp(':calendar-user-address-set')];
            AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
            aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':calendar-user-address-set')]);
            aProp.AppendChild(apropD);
            for b := 0 to aFile.UserAdressSet.Count-1 do
              begin
                aHref := aDocument.CreateElement(prefix+':href');
                aPropD.AppendChild(aHref);
                aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aFile.UserAdressSet[b])));
              end;
            RemoveProp(':calendar-user-address-set');
          end;
        if aFile.IsCalendar then
          begin
            if not aFile.IsCalendarUser then
              begin
                if Assigned(aPropC) then
                  aPropC.AppendChild(aDocument.CreateElement(AddNS('C','urn:ietf:params:xml:ns:caldav')+':calendar'));
                if FindProp(':supported-report-set') > -1 then
                  begin
                    aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':supported-report-set')]);
                    bPrefix := copy(aPropD.NodeName,0,pos(':',aPropD.NodeName)-1);
                    aProp.AppendChild(aPropD);
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(prefix+':supported-report'));
                    aPropF := aPropE.AppendChild(aDocument.CreateElement(prefix+':report'));
                    aPropG := aPropF.AppendChild(aDocument.CreateElement(bPrefix+':calendar-multiget'));
                    RemoveProp(':supported-report-set');
                  end;
                if FindProp(':current-user-privilege-set') > -1 then
                  begin
                    tmp := aNotFoundProp.ValueFromIndex[FindProp(':current-user-privilege-set')];
                    aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':current-user-privilege-set')]);
                    aProp.AppendChild(aPropD);
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(prefix+':privilege'));
                    aPropF := aPropE.AppendChild(aDocument.CreateElement(prefix+':read'));
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(prefix+':privilege'));
                    aPropF := aPropE.AppendChild(aDocument.CreateElement(prefix+':read-acl'));
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(prefix+':privilege'));
                    aPropF := aPropE.AppendChild(aDocument.CreateElement(prefix+':read-current-user-privilege-set'));
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(prefix+':privilege'));
                    aPropF := aPropE.AppendChild(aDocument.CreateElement(prefix+':write'));
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(prefix+':privilege'));
                    aPropF := aPropE.AppendChild(aDocument.CreateElement(prefix+':write-acl'));
                    RemoveProp(':current-user-privilege-set');
                  end;
                if FindProp(':supported-calendar-component-set') > -1 then
                  begin
                    tmp := aNotFoundProp.ValueFromIndex[FindProp(':supported-calendar-component-set')];
                    AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
                    aPropD := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':supported-calendar-component-set')]);
                    aProp.AppendChild(aPropD);
                    aPropE := aPropD.AppendChild(aDocument.CreateElement(aPrefix+':comp'));
                    TDOMElement(aPropE).SetAttribute('name','VEVENT');
                    if aFile.IsTodoList then
                      begin
                        aPropE := aPropD.AppendChild(aDocument.CreateElement(aPrefix+':comp'));
                        TDOMElement(aPropE).SetAttribute('name','VTODO');
                      end;
                    RemoveProp(':supported-calendar-component-set');
                  end;
              end;
          end;
        if aFile.IsDir then
          begin
            if Assigned(aPropC) then
              aPropC.AppendChild(aDocument.CreateElement(prefix+':collection'));
            if not aFile.IsCalendar then
              begin
                if (FindProp('getcontenttype') > -1)  then
                  begin
                    aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp('getcontenttype')]);
                    RemoveProp('getcontenttype');
                    aPropC.AppendChild(aDocument.CreateTextNode('httpd/unix-directory'));
                    aProp.AppendChild(apropC);
                  end;
              end;
          end;
        for a := 0 to aFile.Properties.Count-1 do
          begin
            if (FindProp(aFile.Properties.Names[a]) > -1) then
              begin
                if (aFile.Properties.Names[a] = 'getcontenttype')
                then
                  aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(aFile.Properties.Names[a])])
                else if pos(':',aFile.Properties.Names[a])=-1 then
                  aPropC := aDocument.CreateElement(prefix+':'+aFile.Properties.Names[a])
                else
                  begin
                    tmp := aNotFoundProp.ValueFromIndex[FindProp(aFile.Properties.Names[a])];
                    case copy(aFile.Properties.Names[a],0,pos(':',aFile.Properties.Names[a])-1) of
                    'C':
                      begin
                        AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
                        aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(aFile.Properties.Names[a])]);
                      end;
                    'CS':
                      begin
                        AddNS(copy(tmp,0,pos(':',tmp)-1),'http://calendarserver.org/ns/');
                        aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(aFile.Properties.Names[a])]);
                      end;
                    'IC':
                      begin
                        AddNS(copy(tmp,0,pos(':',tmp)-1),'http://apple.com/ns/ical/');
                        aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(aFile.Properties.Names[a])]);
                      end;
                    else
                      aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(aFile.Properties.Names[a])]);
                    end;
                  end;
                RemoveProp(aFile.Properties.Names[a]);
                aPropC.AppendChild(aDocument.CreateTextNode(aFile.Properties.ValueFromIndex[a]));
                aProp.AppendChild(aPropC);
              end;
          end;
      end
    else //root dir
      begin
        if (FindProp(':getcontenttype') > -1)  then
          begin
            aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':getcontenttype')]);
            aPropC.AppendChild(aDocument.CreateTextNode('httpd/unix-directory'));
            aProp.AppendChild(apropC);
          end;
        if (FindProp('resourcetype') > -1)  then
          begin
            aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp('resourcetype')]);
            RemoveProp('resourcetype');
            aProp.AppendChild(aPropC);
            aPropC.AppendChild(aDocument.CreateElement(prefix+':collection'));
          end;
      end;
    if (FindProp(':supportedlock') > -1)  then
      begin
        aLock := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':supportedlock')]);
        aLockEntry := aDocument.CreateElement(prefix+':lockentry');
        aLock.AppendChild(aLockEntry);
        aLockEntry.AppendChild(aDocument.CreateElement(prefix+':lockscope').AppendChild(aDocument.CreateElement(prefix+':exclusive')));
        aLockEntry.AppendChild(aDocument.CreateElement(prefix+':locktype').AppendChild(aDocument.CreateElement(prefix+':write')));
        aProp.AppendChild(aLock);
      end;
    aStatus := aDocument.CreateElement(prefix+':status');
    aPropStat.AppendChild(aStatus);
    aTextNode := aDocument.CreateTextNode(BuildStatus(200,'OK'));
    aStatus.AppendChild(atextNode);
    if aNotFoundProp.Count>0 then
      begin
        aPropStat := aDocument.CreateElement(prefix+':propstat');
        aResponse.AppendChild(aPropStat);
        aProp := aDocument.CreateElement(prefix+':'+'prop');
        aPropStat.AppendChild(aProp);
        for a := 0 to aNotFoundProp.Count-1 do
          begin
            if FindProp(aNotFoundProp.ValueFromIndex[a])>-1 then
              tmp := aNotFoundProp.ValueFromIndex[FindProp(aNotFoundProp.ValueFromIndex[a])]
            else tmp := '';
            case copy(aNotFoundProp.ValueFromIndex[a],0,pos(':',aNotFoundProp.ValueFromIndex[a])-1) of
            'C':
              begin
                AddNS(copy(tmp,0,pos(':',tmp)-1),'urn:ietf:params:xml:ns:caldav');
                aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[a]);
              end;
            'CS':
              begin
                AddNS(copy(tmp,0,pos(':',tmp)-1),'http://calendarserver.org/ns/');
                aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[a]);
              end;
            else
              aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[a]);
            end;
            aProp.AppendChild(aPropC);
            if BaseApplication.HasOption('debug') then
              writeln('Property not found:'+aNotFoundProp.ValueFromIndex[a]);
          end;
        aStatus := aDocument.CreateElement(prefix+':status');
        aPropStat.AppendChild(aStatus);
          aStatus.AppendChild(aDocument.CreateTextNode(BuildStatus(404,'Not Found')));
      end;
  end;

begin
  Result := inherited HandleXMLRequest(aDocument);
  if BaseApplication.HasOption('debug') then
    writeln('***PROPFIND:'+HTTPDecode(TDAVSocket(FSocket).URI));
  if Assigned(aDocument.DocumentElement) then
    begin
      FindDefaultPrefix(aDocument);
      aMSRes := aDocument.CreateElement(aPrefix+':multistatus');
      ImportNamespaces(aDocument);
      aPropNode := TDOMElement(aDocument.DocumentElement.FirstChild);
      for i := 0 to aPropNode.ChildNodes.Count-1 do
        begin
          tmp := aPropNode.ChildNodes.Item[i].NodeName;
          tmp := copy(tmp,pos(':',tmp)+1,length(tmp));
          tmp1 := copy(aPropNode.ChildNodes.Item[i].NodeName,0,pos(':',aPropNode.ChildNodes.Item[i].NodeName)-1);
          aChildNode := aPropNode.ChildNodes.Item[i];
          if aChildNode.NamespaceURI<>'' then
            tmp := aChildNode.NamespaceURI+':'+tmp
          else
            begin
              if pos(':',tmp)=0 then
                tmp := tmp1+':'+tmp;
            end;
          aProperties.Values[lowercase(tmp)]:=aPropNode.ChildNodes.Item[i].NodeName;
          if BaseApplication.HasOption('debug') then
            writeln('Wanted:'+tmp+'='+aPropNode.ChildNodes.Item[i].NodeName);
        end;
      aDocument.DocumentElement.Free;
    end
  else
    aMSRes := aDocument.CreateElement(aPrefix+':multistatus');
  aDocument.AppendChild(aMSRes);
  if copy(Path,0,1) <> '/' then Path := '/'+Path;
  aDepth := StrToIntDef(trim(FSocket.Parameters.Values['depth']),0);
  aDirList := TDAVDirectoryList.Create;
  TWebDAVServer(FSocket.Creator).Lock;
  Result := DoGetDirectoryList(Path,aDepth,aDirList);
  {
  for i := 1 to aDepth do
    begin
      for a := 0 to aDirList.Count-1 do
        begin
          if (CountOccurences('/',aDirList.Files[a].Path) = aDepth+1)
          and (aDirList.Files[a].IsDir) then
            DoGetDirectoryList(aDirList.Files[a].Path,aDepth,aDirList);
        end;
    end;
  }
  TWebDAVServer(FSocket.Creator).Unlock;
  if Assigned(aDirList) then
    begin
      if not aDirList.HasPath(Path) then
        Createresponse(Path,aMSres,aProperties,aNS,aPrefix);
      if copy(Path,length(Path),1) <> '/' then
        Path := Path+'/';
      for i := 0 to aDirList.Count-1 do
        begin
          if aDirList[i].Path='' then
            Createresponse(Path+aDirList[i].Name,aMSres,aProperties,aNs,aPrefix,aDirList[i])
          else
            Createresponse(aDirList[i].Path+aDirList[i].Name,aMSres,aProperties,aNs,aPrefix,aDirList[i]);
        end;
    end
  else if Assigned(aDirList) and (aDirList is TDAVFile) then
    begin
      Createresponse(Path,aMSres,aProperties,aNs,aPrefix,TDAVFile(aDirList));
    end;
  aDirList.Free;
  TDAVSocket(FSocket).Status:=207;
  TWebDAVServer(FSocket.Creator).Lock;
  if Assigned(TWebDAVServer(FSocket.Creator).OnReadAllowed) and (not TWebDAVServer(FSocket.Creator).OnReadAllowed(TDAVSocket(FSocket),Path)) then
    begin
      TDAVSocket(FSocket).Status:=401;
      TDAVSocket(FSocket).HeaderOut.Add('WWW-Authenticate: Basic realm="Promet-ERP"');
      Result := True;
    end;
  TWebDAVServer(FSocket.Creator).Unlock;
end;
function TDAVReportOutput.HandleXMLRequest(aDocument: TXMLDocument): Boolean;
var
  aItems: TStringList;
  i: Integer;
  bProperties: TStringList;
  tmp: DOMString;
  tmp1: String;
  a: Integer;
  Attr: TDOMNode;
  aAttrPrefix: String;
  aLocalName: String;
  Attr1: TDOMAttr;
  aNSName: String;
  tmp2: DOMString;
  aDirList : TDAVDirectoryList;
  aNode: TDOMNode;
  aFilter : string = '';

  procedure CreateResponse(aPath : string;aParent : TDOMElement;Properties : TStrings;ns : string = 'DAV:';prefix : string = 'D');
  var
    aResponse: TDOMElement;
    aHref: TDOMElement;
    aPropStat: TDOMElement;
    aStatus: TDOMElement;
    aPropC: TDOMElement;
    aProp: TDOMElement;
    a: Integer;
    aLock: TDOMElement;
    aLockEntry: TDOMElement;
    aPropD: TDOMNode;
    aPropE: TDOMNode;
    aPropF: TDOMNode;
    b: Integer;
    aPropG: TDOMNode;
    aStream : TStringStream;
    FLastModified : TDateTime;
    FMimeType,FeTag : string;
  begin
    if BaseApplication.HasOption('debug') then
      writeln('CreateResponse:'+aPath+' '+prefix);
    if Assigned(TWebDAVServer(FSocket.Creator).OnAccess) then
      TWebDAVServer(FSocket.Creator).OnAccess(FSocket,'>'+aPath+' '+prefix);
    aNotFoundProp.Assign(Properties);
    aResponse := aDocument.CreateElement(prefix+':response');
    aParent.AppendChild(aResponse);
    aHref := aDocument.CreateElement(prefix+':href');
    aResponse.AppendChild(aHref);
    aHRef.AppendChild(aDocument.CreateTextNode(InternURLEncode(aPath)));
    aPropStat := aDocument.CreateElement(prefix+':propstat');
    aResponse.AppendChild(aPropStat);
    aProp := aDocument.CreateElement(prefix+':'+'prop');
    aPropStat.AppendChild(aProp);

    aStream := TStringStream.Create('');
    if Assigned(TWebDAVServer(FSocket.Creator).FGet) then
      TWebDAVServer(FSocket.Creator).FGet(TDAVSocket(FSocket),aPath,aStream,FLastModified,FMimeType,FeTag);
    if (FindProp(':getetag') > -1) and (FeTag<>'')  then
      begin
        aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':getetag')]);
        aPropC.AppendChild(aDocument.CreateTextNode(FeTag));
        aProp.AppendChild(apropC);
        removeProp(':getetag');
      end;
    if (FindProp(':calendar-data') > -1) and (aStream.DataString<>'')  then
      begin
        aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[FindProp(':calendar-data')]);
        aPropC.AppendChild(aDocument.CreateTextNode(aStream.DataString));
        aProp.AppendChild(apropC);
        removeProp(':calendar-data');
      end;

    aStream.Free;
    aStatus := aDocument.CreateElement(prefix+':status');
    aPropStat.AppendChild(aStatus);
    aStatus.AppendChild(aDocument.CreateTextNode(BuildStatus(200,'OK')));
    if aNotFoundProp.Count>0 then
      begin
        aPropStat := aDocument.CreateElement(prefix+':propstat');
        aResponse.AppendChild(aPropStat);
        aProp := aDocument.CreateElement(prefix+':'+'prop');
        aPropStat.AppendChild(aProp);
        for a := 0 to aNotFoundProp.Count-1 do
          begin
            aPropC := aDocument.CreateElement(aNotFoundProp.ValueFromIndex[a]);
            aProp.AppendChild(aPropC);
            if BaseApplication.HasOption('debug') then
              writeln('Property not found:'+aNotFoundProp.ValueFromIndex[a]);
          end;
        aStatus := aDocument.CreateElement(prefix+':status');
        aPropStat.AppendChild(aStatus);
        aStatus.AppendChild(aDocument.CreateTextNode(BuildStatus(404,'Not Found')));
      end;
  end;
  procedure RecourseFilter(aNode : TDOMNode);
  var
    b: Integer;
  begin
    if pos(':vevent',lowercase(aNode.NodeName))>0 then

    for b := 0 to aNode.ChildNodes.Count-1 do
      RecourseFilter(aNode.ChildNodes[i]);
  end;

begin
  result := Inherited HandleXMLRequest(aDocument);
  bProperties := TStringList.Create;
  if BaseApplication.HasOption('debug') then
    writeln('***REPORT:'+HTTPDecode(TDAVSocket(FSocket).URI));
  aItems := TStringList.Create;
  Path := HTTPDecode(TDAVSocket(FSocket).URI);
  if pos(#0,path)>0 then
    Path := copy(Path,0,pos(#0,Path)-1);
  if copy(Path,0,1) <> '/' then Path := '/'+Path;
  if Assigned(aDocument.DocumentElement) then
    begin
      FindDefaultPrefix(aDocument);
      aMSRes := aDocument.CreateElement(aPrefix+':multistatus');
      ImportNamespaces(aDocument);
      aPropNode := TDOMElement(aDocument.DocumentElement.FindNode(aPrefix+':prop'));
      if Assigned(aPropNode) then
      for i := 0 to aPropNode.ChildNodes.Count-1 do
        begin
          tmp := aPropNode.ChildNodes.Item[i].NodeName;
          tmp := copy(tmp,pos(':',tmp)+1,length(tmp));
          tmp1 := copy(aPropNode.ChildNodes.Item[i].NodeName,0,pos(':',aPropNode.ChildNodes.Item[i].NodeName)-1);
          if aPropNode.ChildNodes.Item[i].NamespaceURI<>'' then
            tmp := aPropNode.ChildNodes.Item[i].NamespaceURI+':'+tmp
          else
            begin
              for a := 0 to aDocument.DocumentElement.Attributes.Length-1 do
                begin
                  Attr := aDocument.DocumentElement.Attributes[a];
                  aAttrPrefix := copy(Attr.NodeName,0,pos(':',Attr.NodeName)-1);
                  aLocalName := copy(Attr.NodeName,pos(':',Attr.NodeName)+1,length(Attr.NodeName));
                  if (aAttrPrefix = 'xmlns') and (aLocalName = tmp1) then
                    begin
                      case lowercase(Attr.NodeValue) of
                      'dav:':tmp := 'D:'+tmp;
                      'urn:ietf:params:xml:ns:caldav':tmp := 'C:'+tmp;
                      'http://calendarserver.org/ns/':tmp := 'CS:'+tmp;
                      'http://apple.com/ns/ical/':tmp := 'IC:'+tmp;
                      end;
                    end;
                  if (aAttrPrefix = 'xmlns') then
                    begin
                      Attr1 := aDocument.DocumentElement.OwnerDocument.CreateAttribute('xmlns:'+aLocalName);
                      Attr1.Value:=Attr.NodeValue;
                      aMSRes.Attributes.setNamedItemNS(Attr1);
                    end;
                end;
              if pos(':',tmp)=0 then
                tmp := tmp1+':'+tmp;
            end;
          aProperties.Values[lowercase(tmp)]:=aPropNode.ChildNodes.Item[i].NodeName;
          if BaseApplication.HasOption('debug') then
            writeln('Wanted:'+tmp+'='+aPropNode.ChildNodes.Item[i].NodeName);
        end;
      aPropNode := TDOMElement(aDocument.DocumentElement);
      for i := 0 to aPropNode.ChildNodes.Count-1 do
        begin
          tmp := aPropNode.ChildNodes.Item[i].NodeName;
          if pos(':href',lowercase(tmp)) > 0 then
            aItems.Add(aPropNode.ChildNodes.Item[i].FirstChild.NodeValue);
          if pos(':filter',lowercase(tmp)) > 0 then
            begin
              RecourseFilter(aPropNode.ChildNodes.Item[i]);
            end;
        end;
      if aItems.Count=0 then
        begin //we report all ??!
          aDirList := TDAVDirectoryList.Create;
          TWebDAVServer(TDAVSocket(FSocket).Creator).Lock;
          if TWebDAVServer(TDAVSocket(FSocket).Creator).FGetDirList(TDAVSocket(FSocket),Path,1,aDirList) then
            for i := 0 to aDirList.Count-1 do
              begin
                aItems.Add(Path+aDirList[i].Name);
              end;
          TWebDAVServer(TDAVSocket(FSocket).Creator).Unlock;
          aDirList.Free;
        end;
      aDocument.DocumentElement.Free;
    end
  else
    aMSRes := aDocument.CreateElement(aPrefix+':multistatus');
  aDocument.AppendChild(aMSRes);
  aDepth := StrToIntDef(trim(FSocket.Parameters.Values['depth']),0);
  for i := 0 to aItems.Count-1 do
    begin
      bProperties.Assign(aProperties);
      CreateResponse(aItems[i],aMSRes,bProperties,aNs,aPrefix);
    end;
  bProperties.Free;
  aItems.Free;
  TDAVSocket(FSocket).Status:=207;
  Result:=True;
end;
function TDAVDeleteOutput.HandleXMLRequest(aDocument: TXMLDocument): Boolean;
var
  aPath: String;
begin
  Result := inherited HandleXMLRequest(aDocument);
  TWebDAVServer(FSocket.Creator).Lock;
  aPath := HTTPDecode(TDAVSocket(FSocket).URI);
  if pos(#0,apath)>0 then
    aPath := copy(aPath,0,pos(#0,aPath)-1);
  if Assigned(TWebDAVServer(FSocket.Creator).OnDelete) then
    Result := TWebDAVServer(FSocket.Creator).OnDelete(TDAVSocket(FSocket),aPath);
  TWebDAVServer(FSocket.Creator).Unlock;
  if Result then
    FSocket.FStatus:=200
  else
    FSocket.FStatus:=403;
end;
function TDAVMkColOutput.HandleXMLRequest(aDocument: TXMLDocument): Boolean;
var
  aPath: String;
begin
  Result := inherited HandleXMLRequest(aDocument);
  aPath := HTTPDecode(TDAVSocket(FSocket).URI);
  if pos(#0,apath)>0 then
    aPath := copy(aPath,0,pos(#0,aPath)-1);
  TWebDAVServer(FSocket.Creator).Lock;
  if Assigned(TWebDAVServer(FSocket.Creator).OnMkCol) then
    Result := TWebDAVServer(FSocket.Creator).OnMkCol(TDAVSocket(FSocket),aPath);
  TWebDAVServer(FSocket.Creator).Unlock;
end;


end.

