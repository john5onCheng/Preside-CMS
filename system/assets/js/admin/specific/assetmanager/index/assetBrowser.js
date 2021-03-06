( function( $ ){

	var $tree  = $( ".preside-tree-nav" )
	  , $nodes = $tree.find( ".tree-node" )
	  , $listingTable     = $( '#asset-listing-table' )
	  , $tableHeaders     = $listingTable.find( 'thead > tr > th')
	  , $titleAndActions  = $( '.title-and-actions-container' ).first()
	  , $pageSubtitle     = $( '.page-subtitle' ).first()
	  , colConfig         = []
	  , assets            = i18n.translateResource( "preside-objects.asset:title" )
	  , activeFolder      = cfrequest.folder || ""
	  , activeFolderTitle = ""
	  , dataTable, i, nodeClickHandler, presideTreeNav, setupCheckboxBehaviour, enabledContextHotkeys, setupMultiActionButtons;

	nodeClickHandler = function( $node, e ){
		var newActiveFolder = $node.data( "folderId" ) || ""
		  , $clickedElement = $( e.target );

		$nodes.removeClass( "selected" );
		$node.addClass( "selected" );

		if ( $clickedElement.hasClass( 'folder-name' ) && $node.parent().hasClass( 'tree-folder' ) ) {
			presideTreeNav.toggleNode( $node.parent() );
		}

		if ( activeFolder !== newActiveFolder ) {
			$.ajax({
				  url     : buildAjaxLink( "assetmanager.getFolderTitleAndActions" )
				, data    : { folder : newActiveFolder }
				, method  : "POST"
				, success : function( html ){
					activeFolder = newActiveFolder;
					$titleAndActions.html( html );
					$pageSubtitle.html( $node.find( '.folder-name:first' ).html() );

					dataTable && dataTable.fnPageChange( 'first' );
				}
			});

		}
	};

	setupCheckboxBehaviour = function(){
	  	var $selectAllCBox   = $listingTable.find( "th input:checkbox" )
	  	  , $multiActionBtns = $( "#multi-action-buttons" );

		$selectAllCBox.on( 'click' , function(){
			var $allCBoxes = $listingTable.find( 'tr > td:first-child input:checkbox' );

			$allCBoxes.each( function(){
				this.checked = $selectAllCBox.is( ':checked' );
				$(this).closest('tr').toggleClass('selected');
			});
		});

		$multiActionBtns.data( 'hidden', true );
		$listingTable.on( "click", "th input:checkbox,tbody tr > td:first-child input:checkbox", function( e ){
			var anyBoxesTicked = $listingTable.find( 'tr > td:first-child input:checkbox:checked' ).length;

			enabledContextHotkeys( !anyBoxesTicked );

			if ( anyBoxesTicked && $multiActionBtns.data( 'hidden' ) ) {
				$multiActionBtns
					.slideDown( 250 )
					.data( 'hidden', false )
					.find( "button" ).prop( 'disabled', false );

			} else if ( !anyBoxesTicked && !$multiActionBtns.data( 'hidden' ) ) {
				$multiActionBtns
					.slideUp( 250 )
					.data( 'hidden', true )
					.find( "button" ).prop( 'disabled', true );
			}
		} );
	};

	setupMultiActionButtons = function(){
		var $form              = $( '#multi-action-form' )
		  , $hiddenActionField = $form.find( '[name=multiAction]' );

		$( "#multi-action-buttons button" ).click( function( e ){
			$hiddenActionField.val( $( this ).attr( 'name' ) );
		} );
	};

	enabledContextHotkeys = function( enabled ){
		$listingTable.find( 'tbody > tr' ).each( function(){
			if ( enabled ) {
				$( this ).attr( 'data-context-container', '1' );
			} else {
				$( this ).removeAttr( 'data-context-container' );
			}
		} );
	};

	$tree.presideTreeNav( {
		  onClick      : nodeClickHandler
		, collapseIcon : "fa-folder-open"
		, expandIcon   : "fa-folder"
	} );
	presideTreeNav = $tree.data( 'presideTreeNav' );

	colConfig.push( {
		sClass    : "center",
		bSortable : false,
		mData     : "_checkbox",
		sWidth    : "5em"
	} );
	for( i=1; i < $tableHeaders.length-1; i++ ){
		colConfig.push( {
			  mData  : $( $tableHeaders.get(i) ).data( 'field' )
			, sWidth : $( $tableHeaders.get(i) ).data( 'width' ) || 'auto'
		} );
	}
	colConfig.push( {
		sClass    : "center",
		bSortable : false,
		sWidth    : "8em",
		mData     : "_options"
	} );

	dataTable = $listingTable.dataTable( {
		aoColumns     : colConfig,
		bServerSide   : true,
		sAjaxSource   : buildAjaxLink( "assetmanager.assetsForListingGrid" ),
		fnServerParams: function ( aoData ) {
	    	aoData.push( { name : "folder", value : activeFolder } );
		},
		bProcessing   : false,
		bStateSave    : false,
		bPaginate     : false,
		bLengthChange : false,
		aaSorting     : [],
		sDom          : "t",
		fnRowCallback : function( row ){
			$row = $( row );
			$row.attr( 'data-context-container', "1" ); // make work with context aware Preside hotkeys system
			$row.addClass( "clickable" ); // make work with clickable tr Preside system
		},

		oLanguage : {
			oAria : {
				sSortAscending : i18n.translateResource( "cms:datatables.sortAscending", {} ),
				sSortDescending : i18n.translateResource( "cms:datatables.sortDescending", {} )
			},
			oPaginate : {
				sFirst : i18n.translateResource( "cms:datatables.first", { data : [assets], defaultValue : "" } ),
				sLast : i18n.translateResource( "cms:datatables.last", { data : [assets], defaultValue : "" } ),
				sNext : i18n.translateResource( "cms:datatables.next", { data : [assets], defaultValue : "" } ),
				sPrevious : i18n.translateResource( "cms:datatables.previous", { data : [assets], defaultValue : "" } )
			},
			sEmptyTable : i18n.translateResource( "cms:datatables.emptyTable", { data : [assets], defaultValue : "" } ),
			sInfo : i18n.translateResource( "cms:datatables.info", { data : [assets], defaultValue : "" } ),
			sInfoEmpty : i18n.translateResource( "cms:datatables.infoEmpty", { data : [assets], defaultValue : "" } ),
			sInfoFiltered : i18n.translateResource( "cms:datatables.infoFiltered", { data : [assets], defaultValue : "" } ),
			sInfoThousands : i18n.translateResource( "cms:datatables.infoThousands", { data : [assets], defaultValue : "" } ),
			sLengthMenu : i18n.translateResource( "cms:datatables.lengthMenu", { data : [assets], defaultValue : "" } ),
			sLoadingRecords : i18n.translateResource( "cms:datatables.loadingRecords", { data : [assets], defaultValue : "" } ),
			sProcessing : i18n.translateResource( "cms:datatables.processing", { data : [assets], defaultValue : "" } ),
			sZeroRecords : i18n.translateResource( "cms:datatables.zeroRecords", { data : [assets], defaultValue : "" } ),
			sSearch : '',
			sUrl : '',
			sInfoPostFix : ''
		}
	} );

	setupCheckboxBehaviour();
	setupMultiActionButtons();

} )( presideJQuery );