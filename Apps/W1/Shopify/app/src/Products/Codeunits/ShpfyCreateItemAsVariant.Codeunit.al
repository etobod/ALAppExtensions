namespace Microsoft.Integration.Shopify;

using Microsoft.Inventory.Item;

codeunit 30343 "Shpfy Create Item As Variant"
{
    TableNo = Item;
    Access = Internal;

    var
        Shop: Record "Shpfy Shop";
        ShopifyProduct: Record "Shpfy Product";
        CreateProduct: Codeunit "Shpfy Create Product";
        VariantApi: Codeunit "Shpfy Variant API";
        ProductApi: Codeunit "Shpfy Product API";
        Events: Codeunit "Shpfy Product Events";
        Options: Dictionary of [Text, Text];

    trigger OnRun()
    begin
        CreateVariantFromItem(Rec);
    end;

    /// <summary>
    /// Creates a variant from a given item and adds it to the parent product.
    /// </summary>
    /// <param name="Item">The item to be added as a variant.</param>
    internal procedure CreateVariantFromItem(var Item: Record "Item")
    var
        TempShopifyVariant: Record "Shpfy Variant" temporary;
    begin
        if Item.SystemId = ShopifyProduct."Item SystemId" then
            exit;

        CreateProduct.CreateTempShopifyVariantFromItem(Item, TempShopifyVariant);
        TempShopifyVariant.Title := Item."No.";
        if Options.Count = 1 then
            TempShopifyVariant."Option 1 Name" := CopyStr(Options.Values.Get(1), 1, MaxStrLen(TempShopifyVariant."Option 1 Name"))
        else
            TempShopifyVariant."Option 1 Name" := 'Variant';
        TempShopifyVariant."Option 1 Value" := Item."No.";

        Events.OnAfterCreateTempShopifyVariant(Item, TempShopifyVariant);
        TempShopifyVariant.Modify();

        if VariantApi.AddProductVariant(TempShopifyVariant, ShopifyProduct.Id, "Shpfy Variant Create Strategy"::DEFAULT) then begin
            ShopifyProduct."Has Variants" := true;
            ShopifyProduct.Modify(true);
        end;
    end;


    /// <summary>
    /// Checks if items can be added as variants to the product. The items cannot be added as variants if:
    /// - The product has more than one option.
    /// - The UoM as Variant setting is enabled.
    /// </summary>
    internal procedure CheckProductAndShopSettings()
    var
        MultipleOptionsErr: Label 'The product has more than one option. Items cannot be added as variants to a product with multiple options.';
        UOMAsVariantEnabledErr: Label 'Items cannot be added as variants to a product with the "%1" setting enabled for this store.', Comment = '%1 - UoM as Variant field caption';
    begin
        if Shop."UoM as Variant" then
            Error(UOMAsVariantEnabledErr, Shop.FieldCaption("UoM as Variant"));

        Options := ProductApi.GetProductOptions(ShopifyProduct.Id);

        if Options.Count > 1 then
            Error(MultipleOptionsErr);
    end;

    /// <summary>
    /// Sets the parent product to which the variant will be added.
    /// </summary>
    /// <param name="ShopifyProductId">The parent Shopify product ID.</param>
    internal procedure SetParentProduct(ShopifyProductId: BigInteger)
    begin
        ShopifyProduct.Get(ShopifyProductId);
        SetShop(ShopifyProduct."Shop Code");
    end;

    local procedure SetShop(ShopCode: Code[20])
    begin
        Shop.Get(ShopCode);
        VariantApi.SetShop(Shop);
        ProductApi.SetShop(Shop);
        CreateProduct.SetShop(Shop);
    end;

}