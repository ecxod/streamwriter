{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2012 Alexander Nottelmann

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 3
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
    ------------------------------------------------------------------------
}
unit PluginFAAC;

interface

uses
  SysUtils, Windows, Classes, PluginBase, LanguageObjects, Functions, TypeDefs;

type
  TPluginFAAC = class(TPluginBase)
  private
    FEXEPath: string;
  protected
  public
    constructor Create;

    function Copy: TPluginBase; override;
    procedure Assign(Source: TPluginBase); override;

    procedure Initialize; override;
    function ShowInitMessage(Handle: THandle): Boolean; override;

    function CanEncode(AudioType: TAudioTypes): Boolean; override;

    property EXEPath: string read FEXEPath;
  end;

implementation

uses
  AppData;

{ TPluginFAAC }

procedure TPluginFAAC.Assign(Source: TPluginBase);
begin
  inherited;

  FName := Source.Name;
  FHelp := Source.Help;
  FDownloadName := Source.DownloadName;
  FDownloadPackage := Source.DownloadPackage;
end;

function TPluginFAAC.CanEncode(AudioType: TAudioTypes): Boolean;
begin
  Result := AudioType = atAAC;
end;

function TPluginFAAC.Copy: TPluginBase;
begin
  Result := TPluginFAAC.Create;

  Result.Assign(Self);
end;

constructor TPluginFAAC.Create;
begin
  inherited;

  FName := _('Support encoding of AAC using FAAC');
  FHelp := _('This plugin adds support for encoding of AAC files to the application which is useful for postprocessing of recorded songs.');
  FDownloadName := 'addon_faac';
  FDownloadPackage := 'addon_faac.dll';

  FFilesDir := AppGlobals.TempDir + 'addon_faac\';
  FEXEPath := FFilesDir + 'faac.exe';

  FFilenames.Add('faac.exe');
end;

procedure TPluginFAAC.Initialize;
begin
  inherited;

  FName := _('Support encoding of AAC using FAAC');
  FHelp := _('This plugin adds support for encoding of AAC files to the application which is useful for postprocessing of recorded songs.');
end;

function TPluginFAAC.ShowInitMessage(Handle: THandle): Boolean;
begin
  Result := MsgBox(Handle, _('WARNING:'#13#10'It is not be allowed in some contries to use this plugin because it contains faac.exe ' +
                             'that makes use of some patented technologies. Please make sure you may use these files in your country. ' +
                             'If you are sure you may use these files, press "Yes" to continue.'), _('Warning'), MB_ICONWARNING or MB_YESNO or MB_DEFBUTTON2) = IDYES;
end;

end.
