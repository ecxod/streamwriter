{
    ------------------------------------------------------------------------
    streamWriter
    Copyright (c) 2010-2023 Alexander Nottelmann

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

unit CutTabSearchSilence;

interface

uses
  AppData,
  Buttons,
  Classes,
  Controls,
  Dialogs,
  ExtCtrls,
  Forms,
  Functions,
  Graphics,
  Images,
  LanguageObjects,
  LCLType,
  SharedData,
  StdCtrls,
  Spin,
  MLabeledEdit,
  SysUtils,
  Variants;

type

  { TfrmCutTabSearchSilence }

  TfrmCutTabSearchSilence = class(TForm)
    Label12: TLabel;
    Label13: TLabel;
    pnlNav: TPanel;
    Bevel2: TBevel;
    btnOK: TBitBtn;
    txtSilenceLength: TSpinEdit;
    txtSilenceLevel: TMLabeledSpinEdit;
    procedure btnOKClick(Sender: TObject);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    SilenceLevel: Integer;
    SilenceLength: Integer;
    Okay: Boolean;

    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

procedure TfrmCutTabSearchSilence.btnOKClick(Sender: TObject);
begin
  SilenceLevel := txtSilenceLevel.Control.Value;
  SilenceLength := txtSilenceLength.Value;

  Okay := True;

  Close;
end;

procedure TfrmCutTabSearchSilence.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Key = 27 then
  begin
    Key := 0;
    Close;
  end;

  inherited;
end;

constructor TfrmCutTabSearchSilence.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Language.Translate(Self);

  Okay := False;

  txtSilenceLength.Left := Label12.Left + Label12.Width + 4;
  Label13.Left := txtSilenceLength.Left + txtSilenceLength.Width + 4;

  txtSilenceLevel.Control.Value := AppGlobals.Data.StreamSettings.SilenceLevel;
  txtSilenceLength.Value := AppGlobals.Data.StreamSettings.SilenceLength;

  modSharedData.imgImages.GetIcon(TImages.WAND, Icon);
end;


end.
