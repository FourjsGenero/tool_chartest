IMPORT util
IMPORT xml
IMPORT os

TYPE reportType RECORD
    chr STRING,
    fontname STRING,
    lang STRING,
    fgl_length_semantics STRING
END RECORD

MAIN
DEFINE c STRING  -- representation as char
DEFINE i INTEGER -- representation as integer
DEFINE h STRING  -- representation as hex
DEFINE feinfo_userpreferredlang STRING
DEFINE launch_lang, launch_fgl_length_semantics, launch_fglserver  STRING
DEFINE fontinfo_client, fontinfo_server, fontinfopdf_server STRING
DEFINE fontinfo_client_list, fontinfo_server_list, fontinfopdf_server_list STRING

DEFINE x reportType
DEFINE grw om.SaxDocumentHandler

    OPTIONS FIELD ORDER FORM
    OPTIONS INPUT WRAP
    
    CLOSE WINDOW SCREEN

    -- Build 4st from list of fonts
    CALL build_4st()
    CALL ui.Interface.loadStyles("chartest.4st")
    
    OPEN WINDOW w WITH FORM "chartest"

    DISPLAY FGL_GETENV("LANG") TO lang
    DISPLAY FGL_GETENV("FGL_LENGTH_SEMANTICS") TO fgl_length_semantics
    CALL ui.Interface.frontCall("standard","feinfo",["userPreferredlang"],[feinfo_userpreferredlang])
    DISPLAY BY NAME feinfo_userpreferredlang
    LET c = "A"
    LET i = ORD(c)
    LET h = util.Integer.toHexString(i)
    DISPLAY c TO charfontinfo

    INPUT BY NAME c,i,h,
        fontinfo_client, fontinfo_server, fontinfopdf_server,
        fontinfo_client_list, fontinfo_server_list, fontinfopdf_server_list,
        launch_lang, launch_fgl_length_semantics, launch_fglserver
        ATTRIBUTES(UNBUFFERED, WITHOUT DEFAULTS=TRUE)
        ON ACTION dialogtouched INFIELD c
            LET i = ORD(FGL_DIALOG_GETBUFFER())
            LET h = util.Integer.toHexString(i)
            DISPLAY FGL_DIALOG_GETBUFFER() TO charfontinfo
        ON ACTION dialogtouched INFIELD i
            LET c = ASCII(FGL_DIALOG_GETBUFFER())
            LET h = util.Integer.toHexString(FGL_DIALOG_GETBUFFER())
            DISPLAY c TO charfontinfo
        ON ACTION dialogtouched INFIELD h
            LET i = util.Integer.parseHexString(FGL_DIALOG_GETBUFFER())
            LET c = ASCII(i)
            DISPLAY c TO charfontinfo
            DISPLAY c TO c
            
        ON ACTION launch -- Launch same program but with different environment
            IF launch_lang IS NOT NULL THEN
                CALL FGL_SETENV("LANG", launch_lang)
            END IF
            IF launch_fgl_length_semantics IS NOT NULL THEN
                CALL FGL_SETENV("FGL_LENGTH_SEMANTICS", launch_fgl_length_semantics)
            END IF
             IF launch_fglserver IS NOT NULL THEN
                CALL FGL_SETENV("FGL_SERVER", launch_fglserver)
            END IF
            RUN "fglrun tool_chartest.42r" WITHOUT WAITING
            
        ON CHANGE fontinfo_client -- change style used for field
            CALL ui.Window.getCurrent().getForm().setFieldStyle("charfontinfo",SFMT("%1 %2","bigger",nvl(fontinfo_client, fontinfo_client_list)))
            CALL ui.Window.getCurrent().getForm().setFieldStyle("c",SFMT("%1",nvl(fontinfo_client, fontinfo_client_list)))

        ON CHANGE fontinfo_client_list -- change style used for field
            CALL ui.Window.getCurrent().getForm().setFieldStyle("charfontinfo",SFMT("%1 %2","bigger",nvl(fontinfo_client, fontinfo_client_list)))
            CALL ui.Window.getCurrent().getForm().setFieldStyle("c",SFMT("%1",nvl(fontinfo_client, fontinfo_client_list)))
            
        ON ACTION report_pdf -- generate PDF report
            IF fgl_report_loadCurrentSettings("chartest.4rp") THEN
                LET x.chr = c
                LET x.fontname = nvl(fontinfopdf_server,fontinfopdf_server_list)
                LET x.lang = FGL_GETENV("LANG")
                LET x.fgl_length_semantics = FGL_GETENV("FGL_LENGTH_SEMANTICS")
                CALL fgl_report_selectDevice("PDF")
                CALL fgl_report_selectPreview(TRUE)
                LET grw = fgl_report_commitCurrentSettings()
                START REPORT chartest_rpt TO XML HANDLER grw
                OUTPUT TO REPORT chartest_rpt(x.*)
                FINISH REPORT chartest_rpt
            END IF

        ON ACTION report_svg -- generate SVG report
            IF fgl_report_loadCurrentSettings("chartest.4rp") THEN
                LET x.chr = c
                LET x.fontname = nvl(fontinfo_server,fontinfo_server_list)
                LET x.lang = FGL_GETENV("LANG")
                LET x.fgl_length_semantics = FGL_GETENV("FGL_LENGTH_SEMANTICS")
                CALL fgl_report_selectDevice("SVG")
                CALL fgl_report_selectPreview(TRUE)
                LET grw = fgl_report_commitCurrentSettings()
                START REPORT chartest_rpt TO XML HANDLER grw
                OUTPUT TO REPORT chartest_rpt(x.*)
                FINISH REPORT chartest_rpt
            END IF
            
        
    END INPUT
END MAIN



-- For each font generate a style entry in 4st
FUNCTION build_4st()
DEFINE doc xml.DomDocument
DEFINE root xml.DomNode
DEFINE style, style_attribute xml.DomNode

DEFINE ch base.Channel
DEFINE line STRING

    LET ch = base.Channel.create()
    CALL ch.openFile("fontlist_client.txt","r")

    LET doc = xml.DomDocument.Create()
    CALL doc.load(SFMT("%1%2lib%2default.4st", FGL_GETENV("FGLDIR"),os.Path.separator()))

    LET root = doc.getDocumentElement()
    
    LET style = root.appendChildElement("Style")
    CALL style.setAttribute("name",".bigger")
        
    LET style_attribute = style.appendChildElement("StyleAttribute")
    CALL style_attribute.setAttribute("name","fontSize")
    CALL style_attribute.setAttribute("value","3em")

    WHILE TRUE
        LET line = ch.readLine()
        IF ch.isEof() THEN
            EXIT WHILE
        END IF

        LET style = root.appendChildElement("Style")
        CALL style.setAttribute("name",SFMT(".%1",line))
        
        LET style_attribute = style.appendChildElement("StyleAttribute")
        CALL style_attribute.setAttribute("name","fontFamily")
        CALL style_attribute.setAttribute("value",line)
    END WHILE
    
    CALL doc.save("chartest.4st")
END FUNCTION



-- Populate combobox with list of fonts on GUI client
FUNCTION combo_populate_fontinfo_client(cb)
DEFINE cb ui.ComboBox
DEFINE ch base.Channel
DEFINE line STRING

    -- For now just read a file
    -- TODO figure out some OS command to return this info
    CALL cb.clear()
    LET ch = base.Channel.create()
    CALL ch.openFile("fontlist_client.txt","r")
     WHILE TRUE
        LET line = ch.readLine()
        IF ch.isEof() THEN
            EXIT WHILE
        END IF
        -- Use # as comment, ignore these lines
        IF line MATCHES "#*" THEN
            CONTINUE WHILE
        END IF

        CALL cb.addItem(line,line)
    END WHILE
END FUNCTION



-- Populate combobox with result of fontinfo
FUNCTION combo_populate_fontinfo_server(cb)
DEFINE cb ui.ComboBox
DEFINE ch base.Channel
DEFINE line STRING

    CALL cb.clear()
    LET ch = base.Channel.create()
    CALL ch.openPipe(SFMT("%1%2bin%2fontinfo", FGL_GETENV("GREDIR"), os.Path.separator()),"r")
     WHILE TRUE
        LET line = ch.readLine()
        IF ch.isEof() THEN
            EXIT WHILE
        END IF

        CALL cb.addItem(line,line)
    END WHILE
END FUNCTION



-- Populate combobox with result of fontinfopdf
FUNCTION combo_populate_fontinfopdf_server(cb)
DEFINE cb ui.ComboBox
DEFINE ch base.Channel
DEFINE line STRING

    CALL cb.clear()
    LET ch = base.Channel.create()
    CALL ch.openPipe(SFMT("%1%2bin%2fontinfopdf", FGL_GETENV("GREDIR"), os.Path.separator()),"r")
     WHILE TRUE
        LET line = ch.readLine()
        IF ch.isEof() THEN
            EXIT WHILE
        END IF

        CALL cb.addItem(line,line)
    END WHILE
END FUNCTION



-- Simple report to test output to GRW
REPORT chartest_rpt(x)
DEFINE x reportType
    FORMAT 
        ON EVERY ROW
            PRINTX x.*
END REPORT