{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit pOptions;

interface

uses
  uMandantOptions, uOptions, uOptionsFrame, uProcessOptions, uuseroptions, 
  uSyncOptions, uUserfieldDefOptions, uimportoptions, upaygroups, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('pOptions', @Register);
end.
