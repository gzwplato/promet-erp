program consoletest_webdav;

{$mode objfpc}{$H+}
{.$apptype GUI}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, lazmouseandkeyinput,
  Classes, SysUtils, CustApp,
  mouseandkeyinput,testregistry, fpcunit, //consoletestrunner,

  tLogin,
  tdbtests,
  twebdav,
  tLogout,

  pprometdbintfs,
  pcmdprometapp
  { you can add units after this }
  ,uBaseCustomApplication,uBaseApplication;

type

  { TConsoleTest }

  TConsoleTest = class(TCustomApplication,ITestListener)
  private
    FSuccess: boolean;
    procedure WriteChar(c: char);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    procedure AddFailure(ATest: TTest; AFailure: TTestFailure);
    procedure AddError(ATest: TTest; AError: TTestFailure);
    procedure StartTest(ATest: TTest);
    procedure EndTest(ATest: TTest);
    procedure RunTest(ATest: TTest);
    procedure StartTestSuite(ATestSuite: TTestSuite);
    procedure EndTestSuite(ATestSuite: TTestSuite);
  end;

{ TConsoleTest }

procedure TConsoleTest.DoRun;
var
  ErrorMsg: String;
  testSuite: TTestSuite;
  aResult: TTestResult;
begin
  // parse parameters
  if HasOption('h','help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  testSuite := GetTestRegistry;
  aResult := TTestResult.Create;
  aResult.AddListener(self);
  testSuite.Run(aResult);
  if not aResult.WasSuccessful then
    ExitCode:=1;
  aResult.Free;
  // stop program loop
  Terminate;
end;
procedure TConsoleTest.WriteChar(c: char);
begin
  write(c);
  // flush output, so that we see the char immediately, even it is written to file
  Flush(output);
end;
var
  Application: TConsoleTest;
constructor TConsoleTest.Create(TheOwner: TComponent);
var
  aApp: TConsoleTest;
begin
  inherited Create(TheOwner);
  StopOnException:=True;
  aApp := Application;
  BaseApplication := TBaseCustomApplication.Create(nil);
  Application := aApp;
end;
destructor TConsoleTest.Destroy;
begin
  BaseApplication.Free;
  BaseApplication := nil;
  inherited Destroy;
end;
procedure TConsoleTest.WriteHelp;
begin
  { add your help code he e }
  writeln('Usage: ',ExeName,' -h');
end;
procedure TConsoleTest.AddFailure(ATest: TTest; AFailure: TTestFailure);
begin
  FSuccess := false;
  writechar('F');
end;
procedure TConsoleTest.AddError(ATest: TTest; AError: TTestFailure);
begin
  FSuccess := false;
  writechar('E');
end;
procedure TConsoleTest.StartTest(ATest: TTest);
begin
  FSuccess := true; // assume success, until proven otherwise
end;
procedure TConsoleTest.EndTest(ATest: TTest);
begin
  if FSuccess then
    writechar('.');
end;
procedure TConsoleTest.RunTest(ATest: TTest);
begin
end;
procedure TConsoleTest.StartTestSuite(ATestSuite: TTestSuite);
begin
end;
procedure TConsoleTest.EndTestSuite(ATestSuite: TTestSuite);
begin
end;

begin
  Application:=TConsoleTest.Create(nil);
  Application.Run;
  Application.Free;
end.

