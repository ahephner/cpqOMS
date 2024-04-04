public with sharing class omsCPQAPEX {
//wrapper for returning product info
public with sharing class prodWrapper {
    @AuraEnabled
    public pricebookentry selectedProduct {get; set;}
    @AuraEnabled 
    public productitem inventory {get; set;}
    @AuraEnabled
    public Sales_Doc_Detail__c lastPaid {get; set;}
    @AuraEnabled
    public OpportunityLineItem lastQuote {get;set;}
    @AuraEnabled 
    public Object lastThirty {get;set;}
    @AuraEnabled
    public pricebookentry bestPrice {get;set;}
}

    @AuraEnabled(cacheable = true)
public static list<prodWrapper> getDetailsPricing(string pId, string locationId, string accId, string pc, string recId,string priceBookId, list<string> priceBookIds){
    //wrapper to return to lwc
    List<prodWrapper> prodList = new List<prodWrapper>();
    ProductItem count = null;
    sales_doc_detail__c order = null;
    OpportunityLineItem quoteInfo;
    //set up vars
  string pbId = priceBookId;
  string productId = pId; 
  string pClass = 'Simple';
  string locId = locationId;
  string accountId = accId; 
  string code = pc; 
  string opportunityId = recId; 
  date minusThirty = Date.today().addDays( -30 );
  
    //single product query
  String query = 'Select Id,'
            + '  Product2.ProductCode, Product2.Name, Product2.Product_Status__c, Product2.Product_Family__c, Product2.Subcategory__c, Product2.Ship_Weight__c, Product2.Pallet_Qty__c,'
            + '  Product2.Floor_Type__c, Product2.Floor_Price__c, Product2.Last_Purchase_Price__c, Agency_Product__c, product2.Total_Product_Items__c, Product2.Temp_Unavailable__c,'
              + ' Floor_Price__c, Level_1_UserView__c, Level_One_Margin__c, Level_2_UserView__c, Level_2_Margin__c, Product_Cost__c, Product2.Temp_Mess__c, Product2.SGN__c,'
              + ' Product2.RUP__c'
            + ' From PricebookEntry Where IsActive = True and Pricebook2Id =: pbId AND Product2.ProductClass =:pClass AND Product2Id =:productId' ; 
     list<PricebookEntry> results = Database.query(query);
     
  
    //Inventory query
    list<ProductItem> countList = [select id, QuantityOnHand, Quantity_Available__c from productitem 
                                  where Product_Class__c=:pClass and LocationId =:locId 
                                  and Product2Id =:productId limit 1];
        
    
    //last paid query
    List<sales_doc_detail__c> orderList = [select id,name,Unit_Price__c,Margin__c, Doc_Date__c from sales_doc_detail__c
                                               where Product_Code__c =: code and Sales_Document__r.customer__c =: accountId
                                               order by Sales_Document__r.doc_date__c desc
                                               limit 1];
    
    //last quote
    List<OpportunityLineItem> quoteList = [select Product2Id, Last_Quote_Price__c ,Last_Quote_Margin__c,Quote_Date__c, ProductCode
                                           from OpportunityLineItem where ProductCode =: Code and Account__c =: accountID
                                           and OpportunityId !=:opportunityId
                                               order by LastModifiedDate desc limit 1];
    
    //best price
    list<pricebookentry> lowestPrice = getPriceBooks.getBestPrice(priceBookIds, productId);
    
    AggregateResult [] result = [select sum(qty__c)ttt from Sales_Doc_Detail__c where Product__r.Product_Code__c = :Code and Sales_Document__r.Doc_Date__c >=:minusThirty];
   
    if(!results.isEmpty()){
        for(pricebookentry pb:results){
            prodWrapper pw = new prodWrapper();
            pw.selectedProduct = results[0];
            pw.inventory = countList.size() > 0 ? countList[0] : null;
            pw.lastPaid = orderList.size() > 0 ? orderList[0] : null; 
            pw.lastQuote = quoteList.size() > 0 ? quoteList[0] : null;
            pw.bestPrice = lowestPrice.size()> 0 ? lowestPrice[0] : null;  
            pw.lastThirty = result[0].get('ttt'); 
            prodList.add(pw); 
        }
    }
    
    return prodList; 
}

//save products
@AuraEnabled
public static list<OpportunityLineItem> createProducts(List<OpportunityLineItem> olList, string oppId, string accId){
    
    system.debug(olList);
    //system.debug(accId);
    list<OpportunityLineItem> toUpsert = new list<OpportunityLineItem>();
    list<opportunityLineItem> toReturn = new List<OpportunityLineItem>();
    list<id> newPricebookEntry = new list<id>();
  
        for(OpportunityLineItem x : olList){
        OpportunityLineItem ol = new OpportunityLineItem();
        if(String.isBlank(x.Id)){
            //ol.Id = x.Id;
            //system.debug(x.Ship_Weight__c); 
        ol.PricebookEntryId = x.PricebookEntryId;
        ol.Product2Id = x.Product2Id;
        ol.Quantity = x.Quantity;
        ol.CPQ_Unit_Price__c = x.UnitPrice;
        ol.UnitPrice = x.UnitPrice;
        ol.CPQ_Margin__c = x.CPQ_Margin__c;
        ol.Cost__c = x.Cost__c;
        ol.Description = x.Description;
        ol.Single_Product_Weight__c  = x.Ship_Weight__c;
        ol.Discount = x.Discount; 
        ol.OpportunityId = x.OpportunityId;
        ol.Line_Order__c = x.Line_Order__c; 
        ol.Account__c = accId; 
        ol.altPriceBookEntryId__c = x.altPriceBookEntryId__c;
        ol.altPriceBookId__c = x.altPriceBookId__c;
        ol.altPriceBookName__c = x.altPriceBookName__c;
            newPricebookEntry.add(x.PricebookEntryId);
    }else if(!String.isBlank(x.Id)){
        system.debug(x.UnitPrice);
        system.debug(x.Quantity);
        ol.Id = x.Id; 
        //ol.PricebookEntryId = x.PricebookEntryId;
        //ol.Product2Id = x.Product2Id;
        ol.Quantity = x.Quantity;
        ol.CPQ_Unit_Price__c = x.UnitPrice;
        ol.UnitPrice = x.UnitPrice;
        ol.CPQ_Margin__c = x.CPQ_Margin__c;
        ol.Cost__c = x.Cost__c;
        ol.Single_Product_Weight__c  = x.Ship_Weight__c;
        ol.Description = x.Description;
        ol.Account__c = accId;
        ol.Discount = x.Discount;  
        ol.Line_Order__c = x.Line_Order__c;
        //ol.OpportunityId = x.OpportunityId;
    }
        
  
        toUpsert.add(ol);
    }
          
        
    
    try{
       Database.UpsertResult[] res = Database.upsert(toUpsert);
        toReturn = [select id, pricebookentryid from opportunitylineitem where pricebookentryid in:newPricebookEntry and OpportunityId =: oppId];
        //mess = 'success';
    }catch(exception e){
        //mess = string.valueOf(e);
        system.debug(e); 
    }
    return toReturn; 
}

    //ON LOAD SECTION
//Get products and last paid when a opportunities are loaded!
    //get saved opportunity line items
//!Important to get Product2 fields returned as [id, pricebookentryId, product2Id, Product2{Name, ProductCode}]
//to access on JS side need to put Product2.Name => Returns product name
@AuraEnabled
public static list<OpportunityLineItem> getProducts(string oppId){
    list<string> pricebookentryid = new list<string>();
    list<pricebookentry> pricing = new list<pricebookentry>(); 
    list<OpportunityLineItem> opLi = [select id, pricebookEntryId, product2Id,product2.name,Product2.ProductCode,Product2.Floor_Type__c, TotalPrice,product2.Ship_Weight__c,
                                      product2.Agency_Pricing__c, Quantity, CPQ_Unit_Price__c,CPQ_Margin__c, Cost__c, OpportunityId,Description, Product2.Last_Purchase_Price__c,
                                      Product2.Pallet_Qty__c, Product2.SGN__c, Product2.RUP__c, Line_Order__c, altPriceBookEntryId__c, altPriceBookId__c, altPriceBookName__c
                                      from OpportunityLineItem where opportunityId =: oppId];
    for(OpportunityLineItem x : opLi){
        pricebookentryid.add(x.altPriceBookEntryId__c);
    }
    
    if(pricebookentryid.size()<0){
        pricing = [select id, UnitPrice, Floor_Price__c from pricebookentry where id in:pricebookentryid ]; 
    }
    return opLi; 
}
}