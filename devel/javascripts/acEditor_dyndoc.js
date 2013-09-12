function dirname (path) {
    // Returns the directory name component of the path  
    // 
    // version: 1109.2015
    // discuss at: http://phpjs.org/functions/dirname
    // +   original by: Ozh
    // +   improved by: XoraX (http://www.xorax.info)
    // *     example 1: dirname('/etc/passwd');
    // *     returns 1: '/etc'
    // *     example 2: dirname('c:/Temp/x');
    // *     returns 2: 'c:/Temp'
    // *     example 3: dirname('/dir/test/');
    // *     returns 3: '/dir'
    return path.replace(/\\/g, '/').replace(/\/[^\/]*\/?$/, '');
}

function DyndocACEditor(theme,mode) {

    window.dynedit=this; //to access dynedit everywhere! Assuming there is only one dynedit used!
    this.buffer="";
    this.curUser="";
    this.curFile="";
    this.curPdf="";
    this.sizeMo="0.0Mo";
    this.urlPdf="/rooms/"; //"http://sagag6.upmf-grenoble.fr/rooms/";
    this.theme=0;

    this.layout=new dhtmlXLayoutObject("main", "1C");
    this.layout.cells("a").hideHeader();
    this.layout.cells("a").attachObject("editor");

    //this.uploadWindow = this.layout.dhxWins.createWindow("uploadWindow");


    this.toolbar = this.layout.attachToolbar();
    this.toolbar_create();    
    this.toolbar_event();


    window.aceEditor = ace.edit("editor");
    this.editor = window.aceEditor;

    this.editor_init(theme,mode);
    this.editor_event();

    // context menu for tree
    //this.menu = new dhtmlXMenuObject();
    //this.menu.setIconsPath("../common/images/");
    //this.menu.renderAsContextMenu();
    //this.menu.attachEvent("onClick", onButtonClick);
    //this.menu.attachEvent("onBeforeContextMenu", onButtonClick);
    //this.menu.addCheckbox("child", this.menu.topId, 0, "ignore_case", "Ignore Case", true);


    //define the tree view!!!
    this.layout2 = this.layout.cells("a").view("tree").attachLayout("2U", "dhx_black");
    this.layout2.cells("a").setText("Files tree");
    this.tree = this.layout2.cells("a").attachTree("0");
    
    this.tree.setImagePath("../dHtmlX/imgs/");
    this.tree.enableDragAndDrop(true);
    //PRO ONLY: this.tree.setDragBehavior("sibling"); Finally NOT NEEDED!
    this.tree.setDataMode("json");
    this.tree.loadJSON("/editor/dir?id=0");

    //THIS IS OBSOLETE NOW! MAYBE USE IT LATER FOR A WORLD FILES VIEW
    this.treeWorld = this.layout2.cells("a").view("world").attachTree("0");
    this.treeWorld.setImagePath("/dHtmlX/imgs/");
    this.treeWorld.enableDragAndDrop(false);
    this.treeWorld.enableCheckBoxes(true);
    this.treeWorld.setDataMode("json");
    this.treeWorld.loadJSON("/editor/world_dir?id=0");
    
    this.trees_event();


    this.layout2.cells("b").attachObject("editor-fileuploader");
    this.layout2.cells("b").setText("Files uploader");
    this.uploader_init();

    this.layout.cells("a").view("log").attachObject("log");
    //THIS IS OBSOLOLETE SINCE IT IS BETTER TO SEE THE PAGE IN ANOTHER TAB
    this.layout.cells("a").view("html").attachObject("html");

    this.init_first();
};

DyndocACEditor.prototype = {

    init_first: function() {
        var dynedit=this;
        $.get('/editor/init', function(data) {//I tried first with getJSON but without any success !!!
                var obj=data.split("|||");
                dynedit.curuser_set(obj[0]);
                dynedit.curfile_set(obj[1]);
                dynedit.curpdf_set(obj[2]);
                dynedit.sizeMo_set(obj[3]);
                dynedit.curtheme_set(obj[4]);
                //alert(dynedit.theme);
                dynedit.editor_set_theme(dynedit.theme);
                dynedit.toolbar.setListOptionSelected("theme", "th_"+dynedit.theme);
                //alert("size="+dynedit.sizeMo);
                dynedit.editor_load(dynedit.curFile);
                dynedit.toolbar_init("edit");
                if(dynedit.curFile=="") dynedit.toolbar_action("files");
            },
            "text"
        );
        this.deletion_confirmed=false;

        // $(document).jkey('alt+shift+e',function(key) {
        //     dynedit.toolbar_action("edit");
        // });

        // $(document).jkey('alt+shift+f',function(key) {
        //     dynedit.toolbar_action("files");
        // });

        // $(document).jkey('alt+shift+w',function(key) {
        //     dynedit.toolbar_action("world");
        // });

        // $(document).jkey('alt+shift+h',function(key) {
        //     dynedit.toolbar_action("html");
        // });

        if (window.attachEvent)
            window.attachEvent("onresize",resizeLayout);
        else
            window.addEventListener("resize",resizeLayout, false);


        function resizeLayout(){
            var w=$(window).width();
            $("#main").css('width',w.toString()+"px");
            //alert("resize -> "+w+" et "+$("#main").css('width'));
            // adjust layout
            this.layout.setSizes();
        }
    },

    sizeMo_set: function(mo) {
        this.sizeMo=mo+"Mo";
        this.toolbar.setItemText("sizeMo", this.sizeMo);
    },

    curuser_set: function(user) {
        this.curUser=user;
        //this.urlPdf=this.urlPdf+user+"/";
    },

    curpdf_set: function(pdf) {
        this.curPdf=pdf;
        this.toolbar.setItemText("curpdf", pdf);
        this.layout.cells("a").view("pdf").attachURL(this.urlPdf+this.curPdf+"?state="+Date.now())
        //this.layout.cells("a").view("pdf").attachURL("http://docs.google.com/gview?url="+this.urlPdf+this.curPdf+"%3Fstate%3D"+Date.now()+"&embedded=true");
    },

    curfile_set: function(file) {
        this.curFile=file;
        this.toolbar.setItemText("curfile", this.curFile);
    },

    curtheme_set: function(th) {
        if(th=="") th="0";
        this.theme=parseInt(th);
    },

    //OBSOLETE SOON!
    html_set: function(page) {
        this.layout.cells("a").view("html").attachURL(page);
    },

    log_set: function(log) {
        var msg="<h3>Log view:</h3>\n<pre><code>\n"+log+"</code></pre>";
        $("#log").html(msg);
    },


    editor_init: function(theme,mode) {       
        
        this.modes={};    
        var modes=mode.split(",");

        for(i in modes) {
            //alert("mode:"+modes[i]);
            var LangMode = ace.require("ace/mode/"+modes[i]).Mode;
            this.modes[modes[i]]=new LangMode();
        }
        var LangMode = ace.require("ace/mode/dyndoc_html").Mode;
        this.modes["dyndoc"]=new LangMode();
        var LangMode = ace.require("ace/mode/r").Mode;
        this.modes["r"]=new LangMode();

        this.themes=theme.split(","); 

        var thOpts = new Array();

        for(i in this.themes) {
            thOpts.push(Array('th_'+i, 'obj', this.themes[i]));
        } 
        this.toolbar.addSeparator("sep_theme",  1000);
        this.toolbar.addButtonSelect("theme", 1001, "Theme", thOpts, "ToolBar/imgs/database.gif", "",true,true,15);
      
    },


    editor_set_theme: function(i) {
        if(i!=this.theme) this.theme=i;
        this.editor.setTheme("ace/theme/"+this.themes[this.theme]);
    },

    editor_init_mode: function() {
        var ext=this.curFile.split(".").pop();
        switch(ext.toLowerCase()) {
            case "r":
                this.mode="r";
                break;
            case "rb":
            case "dyn_cfg":
                this.mode="ruby";
                break;
            case "tex":
                this.mode="latex";
                break;
            default:
                this.mode="dyndoc";
                break;
        }

        this.editor.getSession().setMode(this.modes[this.mode]);
    },

    editor_event: function() {
        var dynedit=this;
        this.editor.getSession().on('change', function() {
            dynedit.toolbar.enableItem("save");
        })

        this.editor.commands.addCommand({
            name: 'saveCommand',
            bindKey: {
            win: 'Ctrl-S',
            mac: 'Command-S',
            sender: 'editor'
            },
            exec: function(env, args, request) {
                //save
                dynedit.editor_save(dynedit.curFile);
            }
        });

        // this.editor.commands.addCommand({
        //     name: 'themeCommand',
        //     bindKey: {
        //     win: 'Ctrl-A',
        //     mac: 'Command-A',
        //     sender: 'editor'
        //     },
        //     exec: function(env, args, request) {
        //         var th=dynedit.theme-1;
        //         if(th<0) th=dynedit.themes.length - 1;
        //         dynedit.editor_set_theme(th);
        //         $.post("/editor/curtheme",{current_theme: th});
        //     }
        // });

        // this.editor.commands.addCommand({
        //     name: 'themeCommand',
        //     bindKey: {
        //     win: 'Ctrl-B',
        //     mac: 'Command-B',
        //     sender: 'editor'
        //     },
        //     exec: function(env, args, request) {
        //         var th=dynedit.theme+1;
        //         if(th==dynedit.themes.length) th=0;
        //         dynedit.editor_set_theme(th);
        //         $.post("/editor/curtheme",{current_theme: th});
        //     }
        // });

        this.editor.commands.addCommand({
            name: 'copyCommand',
            bindKey: {
            win: 'Alt-C',
            mac: 'Command-Alt-C',
            sender: 'editor'
            },
            exec: function(env, args, request) {
                //copy
                dynedit.buffer=dynedit.editor.getCopyText();
            }
        });

        this.editor.commands.addCommand({
            name: 'pasteCommand',
            bindKey: {
            win: 'Alt-V',
            mac: 'Command-Alt-V',
            sender: 'editor'
            },
            exec: function(env, args, request) {
                //paste
                dynedit.editor.insert(dynedit.buffer);
            }
        });

        this.editor.commands.addCommand({
            name: 'filesCommand',
            bindKey: {
            win: 'Alt-F',
            mac: 'Command-F',
            sender: 'editor'
            },
            exec: function(env, args, request) {
                //paste
                dynedit.toolbar_action("files");
            }
        });

        this.editor.commands.addCommand({
            name: 'htmlCommand',
            bindKey: {
            win: 'Alt-X',
            mac: 'Command-X',
            sender: 'editor'
            },
            exec: function(env, args, request) {
                //html
                var ext=dynedit.curFile.split(".").pop();
                switch(ext) {
                case "tex":
                    dynedit.toolbar_action("do_tex");
                    break;
                case "dyn_tex":
                    dynedit.toolbar_action("do_dyntex");
                    break;
                //case "dyn_txtl":
                //case "dyn_ttm":
                case "dyn_html":
                    dynedit.toolbar_action("do_dynweb");
                    break;
                }
            }
        });

    },

    //save callback!
    editor_save: function(filename) {
        var dynedit=this;
        $.post( "/editor/save",
            {filename: filename, content: dynedit.editor.getSession().getValue()},
            function(res){
                dynedit.toolbar.disableItem("save");
                dynedit.sizeMo_set(res);
            },
            "text"
        );
    },

    //load callback!
    editor_load: function(filename) {
        var dynedit=this;
        $.post( "/editor/load",
                "filename="+filename,
                function(html){
                    dynedit.editor.getSession().setValue(html);
                    var fileExt=filename.split('.').pop();                    
                    dynedit.toolbar_init(fileExt);
                },
                "text"
        );
    },

    toolbar_create: function() {
        var toolbar=this.toolbar;

        toolbar.setIconsPath("/images/dhtmlx/");
        var newOpts = Array(Array('new_dir', 'obj', 'Directory', "ToolBar/imgs/open.gif"),Array('new_s1', 'sep'), Array('new_dyntex', 'obj', 'DynTex Document', 'ToolBar/imgs/text_document.gif'), Array('new_dynhtml', 'obj', 'DynHtml Document', 'ToolBar/imgs/text_document.gif'),Array('new_dyn', 'obj', 'Dyndoc Document', 'ToolBar/imgs/text_document.gif'), Array('new_dyncfg', 'obj', 'Dyndoc Config', 'ToolBar/imgs/text_document.gif'),Array('new_s2', 'sep'),Array('new_tex', 'obj', 'Tex Document', 'ToolBar/imgs/text_document.gif'),Array('new_r', 'obj', 'R Document', 'ToolBar/imgs/text_document.gif'),Array('new_rb', 'obj', 'Ruby Document', 'ToolBar/imgs/text_document.gif'));
        var id=0;
        toolbar.addButton("files", id += 1, "", "icons/folders.gif");
        toolbar.setItemToolTip("files", "View files");
        toolbar.addButton("world", id += 1, "", "icons/folders.gif");
        toolbar.setItemToolTip("world", "View world files");
        toolbar.addButton("edit", id += 1, "", "icons/editor.gif");
        toolbar.setItemToolTip("edit", "Edit current file");
        toolbar.addButton("pdf", id += 1, "", "icons/pdf.gif");
        toolbar.setItemToolTip("pdf", "View current pdf");
        toolbar.addButton("html", id += 1, "", "icons/file_link.gif");
        toolbar.setItemToolTip("html", "Html view");
        toolbar.addButton("log", id += 1, "", "icons/vault.gif");
        toolbar.setItemToolTip("log", "Log view");
        toolbar.addSeparator("sep1",id += 1 );
        toolbar.addButtonSelect("new", id += 1, "New", newOpts, "ToolBar/imgs/new.gif", "ToolBar/imgs/new_dis.gif");
        toolbar.setItemToolTip("new", "New file or directory");
        toolbar.addButton("save", id += 1, "", "ToolBar/imgs/save.gif", "ToolBar/imgs/save_dis.gif");
        toolbar.setItemToolTip("save", "Save selected document");
        toolbar.addButtonTwoState("copy_or_move",id += 1,"","ToolBar/imgs/save_as.gif",null);
        toolbar.setItemToolTip("copy_or_move", "Drag mode double states button:\n\t=> Unselected: MOVE files\n\t=> Selected: COPY files");
        toolbar.addButton("delete", id += 1, "", "Menu/imgs/close.gif", "Menu/imgs/close_dis.gif");
        toolbar.setItemToolTip("delete", "Delete the selected object");
        toolbar.addButton("rename", id += 1, "", "ToolBar/imgs/cut.gif", "ToolBar/imgs/cut_dis.gif");
        toolbar.setItemToolTip("rename", "Rename the selected object");
        toolbar.addInput("newfile",id += 1 , "fileName",100);
        toolbar.addText("curfile", id += 1, this.curFile);
        toolbar.addText("curpdf", id += 1,  this.curPdf);
        toolbar.addText("delete_ask", id += 1, "Click again to confirm deletion!");
        toolbar.addSeparator("sep2", id += 1);
        toolbar.addButton("do_tex", id += 1, "", "ToolBar/imgs/undo.gif", "ToolBar/imgs/undo_dis.gif");
        toolbar.addButton("do_dyntex", id += 1, "", "ToolBar/imgs/undo.gif", "ToolBar/imgs/undo_dis.gif");
        toolbar.addButton("do_dynweb",id += 1 , "", "ToolBar/imgs/undo.gif", "ToolBar/imgs/undo_dis.gif");
        toolbar.addButtonTwoState("do_siteweb",id += 1,"","ToolBar/imgs/undo.gif",null);
        toolbar.addSeparator("sep3", id += 1);
        toolbar.addText("sizeMo", id += 1, this.sizeMo);
        toolbar.setItemToolTip("do_dyntex", "Go Dyndoc");
        toolbar.setItemToolTip("do_dynweb", "View in new tab");
        toolbar.setItemToolTip("do_siteweb", "Local/World button:\n\t => Unselected: LOCAL\n\t=> Selected: WORLD");
        toolbar.setItemToolTip("do_tex", "Go Latex");
    },

    //view init callback!
    toolbar_init: function(mode) {
        var showItems=new Array();var hideItems=new Array();
        //var enableItems=new Array();var disableItems=new Array();
        switch(mode) {
            case "tree":
                this.layout2.cells("a").setText("Files tree");
                //IMPORTANT: world state is disabled. To reactivate put "world" in first place in showItems!
                showItems.push("edit","pdf","html","log","sep1","new","copy_or_move","delete","rename");
                hideItems.push("files","save","newfile","curfile","curpdf","delete_ask","do_tex","do_dyntex","do_dynweb","do_siteweb","sep_theme","theme");
                var ext=this.curFile.split(".").pop();
                //alert("ext="+ext);
                if(ext=="tex") showItems.push("do_tex");
                if(ext=="dyn_tex") showItems.push("do_dyntex");
                //if(ext=="dyn_txtl") showItems.push("do_dynweb");
                //if(ext=="dyn_ttm") showItems.push("do_dynweb");
                if(ext=="dyn_html") showItems.push("do_dynweb");
                break;
            case "world":
                this.layout2.cells("a").setText("Public files");
                showItems.push("files","edit","pdf","html","log");
                hideItems.push("world","sep1","new","copy_or_move","delete","rename","save","newfile","curfile","curpdf","delete_ask","sep2","do_tex","do_dyntex","do_dynweb","do_siteweb","sep_theme","theme");
                break;
            case "edit":
                showItems.push("files","pdf","html","log","sep1","save","curfile","sep_theme","theme");
                hideItems.push("world","edit","log","new","copy_or_move","delete","rename","delete_ask","newfile","curpdf","do_tex","do_dyntex","do_dynweb","do_siteweb");
                var ext=this.curFile.split(".").pop();
                //alert("ext="+ext);
                if(ext=="tex") showItems.push("do_tex");
                if(ext=="dyn_tex") showItems.push("do_dyntex");
                //if(ext=="dyn_txtl") showItems.push("do_dynweb","do_siteweb");
                //if(ext=="dyn_ttm") showItems.push("do_dynweb","do_siteweb");
                if(ext=="dyn_html") showItems.push("do_dynweb","do_siteweb");
                this.editor_init_mode(); //set the mode of the current file to edit!
                break;
            case "pdf":
                showItems.push("files","edit","log","curpdf");
                hideItems.push("world","pdf","html","sep1","new","save","copy_or_move","delete","rename","delete_ask","newfile","curfile","sep2","do_tex","do_dyntex","do_dynweb","do_siteweb","sep_theme","theme");
                break;
            case "html":
                showItems.push("files","edit","log","curfile");
                hideItems.push("world","pdf","html","sep1","new","save","copy_or_move","delete","rename","delete_ask","newfile","curfile","sep2","do_tex","do_dyntex","do_dynweb","do_siteweb","sep_theme","theme");
                break;
            case "log":
                showItems.push("files","edit","html","curpdf");
                hideItems.push("world","pdf","log","sep1","new","save","copy_or_move","delete","rename","delete_ask","newfile","curfile","sep2","do_tex","do_dyntex","do_dynweb","do_siteweb","sep_theme","theme");
                break;
            case "new":
                showItems.push("newfile");
                hideItems.push("copy_or_move","delete","rename");
                break;
            case "delete":
                showItems.push("delete","delete_ask");
                hideItems.push("newfile","copy_or_move","rename");
                break;
            case "no_compile":
                hideItems.push("sep2","do_tex","do_dyntex","do_dynweb","do_siteweb");
                break;  
            case "tex":
                showItems.push("sep2","do_tex");
                hideItems.push("do_dyntex","do_dynweb","do_siteweb");
                break;
            case "dyn_tex":
                showItems.push("sep2","do_dyntex");
                hideItems.push("do_tex","do_dynweb","do_siteweb");
                break;
            //case "dyn_txtl":
            //case "dyn_ttm":
            case "dyn_html":
                showItems.push("sep2","do_dynweb","do_siteweb");
                hideItems.push("do_tex","do_dyntex");
                break;
        };
        for(id in hideItems) {
            this.toolbar.hideItem(hideItems[id]);
        };
        for(id in showItems) {
            this.toolbar.showItem(showItems[id]);
        };
        //for(id in enableItems) {
        //    this.toolbar.enableItem(enableItems[id]);
        //};
        //for(id in disableItems) {
        //    this.toolbar.disableItem(disableItems[id]);
        //};
    },

    toolbar_action: function(id) {
        var dynedit=window.dynedit;
        switch(id) {
        case "save":
            dynedit.editor_save(dynedit.curFile);
            break;
        case "files":
            dynedit.toolbar_init("tree");
            dynedit.tree_update();
            dynedit.layout.cells("a").view("tree").setActive();
            dynedit.layout2.cells("a").view("def").setActive();
            //layout.cells("a").view("tree").show();
            break;
        case "world":
            dynedit.toolbar_init("world");
            //dynedit.tree_update();
            dynedit.layout.cells("a").view("tree").setActive();
            dynedit.layout2.cells("a").view("world").setActive();
            //layout.cells("a").view("tree").show();
            break;
        case "edit":
            dynedit.toolbar_init("edit");
            dynedit.layout.cells("a").view("def").setActive();
            $('#editor').focus();
            //layout.cells("a").view("def").show();
            break;
        case "pdf":
            dynedit.toolbar_init("pdf");
            //curpdf_set(curPdf);
            dynedit.layout.cells("a").view("pdf").setActive();
            break;
        case "log":
            dynedit.toolbar_init("log");
            dynedit.layout.cells("a").view("log").setActive();
            break; 
        case "new_dir":
            new_doc_type="dir";
            dynedit.toolbar_init("new");
            break;    
        case "new_dyntex":
            new_doc_type="dyn_tex";
            dynedit.toolbar_init("new");
            break;
        //case "new_dyntxtl":
        //    new_doc_type="dyn_txtl";
        //    dynedit.toolbar_init("new");
        //    break;
        //case "new_dynttm":
        //    new_doc_type="dyn_ttm";
        //    dynedit.toolbar_init("new");
        //    break;
        case "new_dynhtml":
            new_doc_type="dyn_html";
            dynedit.toolbar_init("new");
            break;
        case "new_dyn":
            new_doc_type="dyn";
            dynedit.toolbar_init("new");
            break;  
        case "new_dyncfg":
            new_doc_type="dyn_cfg";
            dynedit.toolbar_init("new");
            break;
        case "new_tex":
            new_doc_type="tex";
            dynedit.toolbar_init("new");
            break;
        case "new_r":
            new_doc_type="R";
            dynedit.toolbar_init("new");
            break;
        case "new_rb":
            new_doc_type="rb";
            dynedit.toolbar_init("new");
            break;
        case "rename":
            new_doc_type="rename";
            //alert("|"+dynedit.tree.getSelectedItemId()+"|");
            if(dynedit.tree.getSelectedItemId()!="") {
                dynedit.toolbar_init("new");
            }
            break;
        case "delete":
            if(dynedit.deletion_confirmed) {
                $.post( 
                    "/rooms/delete",
                    {filename: dynedit.tree.getSelectedItemId()},
                    function(res) {
                        dynedit.sizeMo_set(res.split("|||")[1]);
                        dynedit.tree_update();
                        dynedit.toolbar_init("tree");
                        dynedit.deletion_confirmed=false;
                    },
                    "text"
                );
                
            } else {
                dynedit.deletion_confirmed=true;
                dynedit.toolbar_init("delete");
            }
            break;
        case "do_tex":
            $.post( 
                "/play/latex",
                {filename: dynedit.curFile},
                function(data) {
                    var msg=data.split("|||");
                    if(msg[0]=="false") {
                        dynedit.log_set(msg[1]);
                        dynedit.toolbar_init("log");
                        dynedit.layout.cells("a").view("log").setActive();
                    } else {
                        dynedit.log_set("Compilation "+dynedit.curFile+" => okay!!!");
                        dynedit.curpdf_set(dynedit.curFile.replace(/\.tex$/, '.pdf'));
                    } 
                },
                "text"
            );
            
            break;
        case "do_dyntex":
            $.post( "/play/dyntex",
                {filename: dynedit.curFile}
            );
            dynedit.curpdf_set(dynedit.curFile.replace(/\.dyn\_.+$/, '.pdf'));
            break;
        case "do_dynweb":
        //alert("/rooms/"+curFile);
            var newWin=window.open("/site/"+(dynedit.toolbar.getItemState("do_siteweb") ? "world/" : "")+dynedit.curFile,'_blank');
            newWin.focus();
            break;
        case "html":
            //dynedit.toolbar_init("html");
            // dynedit.html_set("/rooms/"+dynedit.curFile);
            // dynedit.layout.cells("a").view("html").setActive();

            //extract the project path
            var file = dynedit.curFile;
            var regFile = /(?:Home|Projects)?\/?(.*)/;
            if(regFile.test(file)) {
                file=regFile.exec(file)[1];
            } else file=null;
            //extract the site_relative_path
            var sitePath=dynedit.editor.getSession().getValue();
            //alert("sitePath="+sitePath);
            var regSitePath = /\[#=\]\s*::document.site_relative_path\s*\[(.*)\]/;
            if(regSitePath.test(sitePath)) {
                sitePath=regSitePath.exec(sitePath)[1];
            } else {
                sitePath=dirname(file);
                //alert("sitePath="+sitePath);
                if(sitePath==file) sitePath=".";
            }
            //alert("file="+file+" and sitePath="+sitePath);
            var newWin=window.open("/world/SitePath/"+sitePath+"/Html/"+file,'_blank');
            newWin.focus();
            break;
        default:
            //theme
            var th=parseInt(id.split("_").pop());
            //alert("th_"+th);
            dynedit.editor_set_theme(th);
            $.post("/editor/curtheme",{current_theme: th});
        };
        if(id!="delete") dynedit.deletion_confirmed=false;
    },

    toolbar_event: function() {
        var dynedit=this; 

        this.toolbar.attachEvent("onClick", this.toolbar_action);

        this.toolbar.attachEvent("onEnter", function(id) {
            var toolbar=this;
            var itemId=dynedit.tree.getSelectedItemId();
            //alert("newfile="+id+":"+toolbar.getValue("newfile")+":"+itemId+":"+tree.hasChildren(itemId)+"->"+tree.getItemText(itemId));
            //rememberItem="";
            $.post(
                "/rooms/new_file",
                {type: new_doc_type , dir: itemId, filename: toolbar.getValue("newfile")},
                function(selected) {
                    //alert("res:"+selected);
                    dynedit.tree_update(selected);
                    dynedit.toolbar_init("tree");
                },
                "text"
            );
        });
    },

    trees_event: function() {
        var dynedit=this;

        this.tree.attachEvent("onDblClick", function(id) {
            var fileExt=id.split('.').pop();
            if(fileExt==id) {
                //alert(id+":"+fileExt+"->"+this.getAllItemsWithKids());
                fileExt="dir";
            }
            switch(fileExt) {
                case "R":
                case "r":
                case "rb":
                case "tex":
                case "dyn_html":
                case "dyn_tex":
                case "dyn":
                case "dyn_cfg":
                    dynedit.curfile_set(id);
                    $.post("/editor/curfile",{current_file: id});
                    dynedit.editor_load(id);
                    dynedit.toolbar_init("edit");
                    dynedit.layout.cells("a").view("def").setActive();
                    break;
                case "pdf":
                    dynedit.curpdf_set(id);
                    $.post("/editor/curpdf",{current_pdf: id});
                    dynedit.toolbar_init("pdf");
                    dynedit.layout.cells("a").view("pdf").setActive();
                    break;
                case "dir":
                    //alert(id+":"+(tree.getOpenState(id)<0));
                    if (this.getOpenState(id)>0) {
                        this.closeItem(id);
                    } else {
                        this.openItem(id);
                    }
                    break;
            };
        });

        this.tree.attachEvent("onClick", function(id) {
            var fileExt=id.split('.').pop();
            if(fileExt==id) {
                //alert(id+":"+fileExt);
                fileExt="dir";
            }
            switch(fileExt) {
                case "R":
                case "r":
                case "rb":
                case "tex":
                case "dyn_tex":
                case "dyn_html":
                case "dyn":
                case "dyn_cfg":
                    dynedit.curfile_set(id);
                    $.post("/editor/curfile",{current_file: id});
                    dynedit.editor_load(id);
                    break;
                case "pdf":
                    dynedit.curpdf_set(id);
                    $.post("/editor/curpdf",{current_pdf: id});
                    dynedit.toolbar_init("no_compile");
                    break;
            };
        });

        this.tree.attachEvent("onDrag",function(sId,tId,id,sObject,tObject) { 
            var valid;
            $.ajax({
                type: "POST",
                url: "/rooms/"+(dynedit.toolbar.getItemState("copy_or_move") ? "copy" : "move"), 
                data: {filename: sId, dir: tId}, 
                async: false, 
                success: function(data) { 
                    //alert(data);
                    valid = (data == "true") ? true : false; 
                },
                dataType: "text"
            });
            //alert(valid);
            return valid; //? confirm("Do you want to move node " + this.getItemText(sId) + " to item " + this.getItemText(tId) + "?") : false;
        });

        this.tree.attachEvent("onDragIn", function(dId,lId,id,sObject,tObject){
            if(dynedit.toolbar.getItemState("copy_or_move")) return true;
            var fileExt=lId.split('.').pop();
            if(fileExt==lId ) {
                //alert(id+":"+fileExt);
                var lDir=(lId=="/" ? "" : "/"+dirname(lId));
                //alert(":"+dirname('/'+dId)+":"+lDir+":")
                if(dirname('/'+dId)==lDir) return false;
                return true;
            } else {
                if (lId.split('@').length>0) {
                    var lDir=(lId=="/" ? "" : "/"+dirname(lId));
                    //alert(":"+dirname('/'+dId)+":"+lDir+":")
                    if(dirname('/'+dId)==lDir) return false;
                    return true;
                }
                return false;
            }
        });

        this.tree.attachEvent("onDrop", function(sId,tId,id,sObject,tObject){
             dynedit.tree_update();
        });

        this.treeWorld.attachEvent("onCheck", function(id,state) {
            $.post("/world/link",{filename: id, state: state},
            function(res) {
               dynedit.treeWorld.setCheck(id,res);
            },"text");
        });

    },


    //tree update
    tree_update: function(selectedItem) {
        //save states
        var allIds=this.tree.getAllItemsWithKids().split(",");
        //alert("allIds->"+allIds.join(","));
        var openIds=new Array();
        for(id in allIds) {
            //alert("id->"+allIds[id]+":"+this.tree.getOpenState(allIds[id]));
            if(this.tree.getOpenState(allIds[id])>0) {
               openIds.push(allIds[id]);
            }
        }
        //alert("openIds->"+openIds.join(","));
        this.tree.deleteChildItems("0");
        this.tree.loadJSON("/editor/dir?id=0&openids="+openIds.join(","));
        if(typeof selectedItem != 'undefined') {
            //alert("tree_updaye="+selectedItem);
            this.tree.selectItem(selectedItem);
            this.tree.focusItem(selectedItem);
            var dirId=selectedItem.split("/").shift();
            //alert("dir:"+dirId);
            this.tree.openItem(dirId);
        }
    },

    uploader_init: function() {
        var dynedit=this;
        //alert("itemId:"+itemId);
        this.uploader = new qq.FileUploader({
            element: document.getElementById('qqfileuploader'),
            action: '/rooms/upload',
            allowedExtensions: 
                ['js','html',
                'tex','dyn','dyn_cfg','dyn_tex','dyn_html',//'dyn_txtl','dyn_ttm',
                'pdf','jpg', 'jpeg', 'png', 'gif',
                'RData','csv'],        
            // each file size limit in bytes
            // this option isn't supported in all browsers
            sizeLimit: 5242880, // max size => 5Mo   
            minSizeLimit: 0, // min size
            // events         
            // you can return false to abort submit
            onSubmit: function(id, fileName){
                var itemId=dynedit.tree.getSelectedItemId();
                dynedit.uploader.setParams({target: itemId});
            },
            //onProgress: function(id, fileName, loaded, total){},
            onComplete: function(id, fileName, responseJSON){
                //alert("toto:"+responseJSON.success+", titi:"+responseJSON.sizeMo);
                dynedit.tree_update();
                dynedit.sizeMo_set(responseJSON.sizeMo);
            },
            //onCancel: function(id, fileName){},
            debug: false
        });
    }
}