(function () {
  const toastHost = document.querySelector("[data-toast]");

  function toast(message, kind = "ok") {
    if (!toastHost) return;
    const el = document.createElement("div");
    el.className = `toast ${kind === "error" ? "err" : "ok"}`;
    el.textContent = message;
    toastHost.appendChild(el);
    setTimeout(() => el.remove(), 4300);
  }

  async function postJson(url, payload) {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload || {}),
    });
    let data = {};
    try {
      data = await res.json();
    } catch (e) {
      data = { success: false, error: "Invalid server response" };
    }
    if (!res.ok && data.success !== true) {
      data.success = false;
    }
    return data;
  }

  async function setUserStatus(userId, status) {
    if (!userId || !status) return;
    const out = await postJson("/admin/update-user-status", { user_id: userId, status });
    toast(out.success ? `User ${status}` : out.error || "Failed to update user", out.success ? "ok" : "error");
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function approveStore(storeId, status) {
    if (!storeId || !status) return;
    const out = await postJson("/admin/approve-store", { store_id: storeId, status });
    toast(out.success ? `Store ${status}` : out.error || "Failed to update store", out.success ? "ok" : "error");
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function removeStore(storeId) {
    if (!storeId || !confirm("Remove this store permanently?")) return;
    const out = await postJson("/admin/remove-store", { store_id: storeId });
    toast(out.success ? "Store removed" : out.error || "Failed to remove store", out.success ? "ok" : "error");
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function addStore(form) {
    const payload = {
      name: form.querySelector("[name='name']").value.trim(),
      owner_id: form.querySelector("[name='owner_id']").value.trim(),
      phone: form.querySelector("[name='phone']").value.trim(),
      address: form.querySelector("[name='address']").value.trim(),
      description: form.querySelector("[name='description']").value.trim(),
    };
    const out = await postJson("/admin/add-store", payload);
    toast(out.success ? "Store added" : out.error || "Failed to add store", out.success ? "ok" : "error");
    if (out.success) form.reset();
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function addShopOwner(form) {
    const payload = {
      name: form.querySelector("[name='name']").value.trim(),
      email: form.querySelector("[name='email']").value.trim(),
      phone: form.querySelector("[name='phone']").value.trim(),
      password: form.querySelector("[name='password']").value,
      store_id: form.querySelector("[name='store_id']").value.trim(),
    };
    const out = await postJson("/admin/add-shop-owner", payload);
    toast(out.success ? "Owner saved" : out.error || "Failed to save owner", out.success ? "ok" : "error");
    if (out.success) form.reset();
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function removeShopOwner(userId) {
    if (!userId || !confirm("Remove owner role from this user?")) return;
    const out = await postJson("/admin/remove-shop-owner", { user_id: userId });
    toast(
      out.success ? "Owner role removed" : out.error || "Failed to remove owner",
      out.success ? "ok" : "error"
    );
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function addDeliveryAgent(form) {
    const payload = {
      name: form.querySelector("[name='name']").value.trim(),
      email: form.querySelector("[name='email']").value.trim(),
      phone: form.querySelector("[name='phone']").value.trim(),
      password: form.querySelector("[name='password']").value,
    };
    const out = await postJson("/admin/add-delivery-agent", payload);
    toast(out.success ? "Delivery agent saved" : out.error || "Failed to save agent", out.success ? "ok" : "error");
    if (out.success) form.reset();
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function assignDelivery(form) {
    const payload = {
      order_id: form.querySelector("[name='order_id']").value.trim(),
      delivery_agent_id: form.querySelector("[name='delivery_agent_id']").value.trim(),
    };
    const out = await postJson("/assign-delivery", payload);
    toast(out.success ? "Delivery assigned" : out.error || "Failed to assign", out.success ? "ok" : "error");
    if (out.success) form.reset();
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function generatePayout(shopOwnerId) {
    if (!shopOwnerId) return;
    const out = await postJson("/weekly-payout", { shop_owner_id: shopOwnerId });
    toast(out.success ? "Payout generated" : out.error || "Failed to generate payout", out.success ? "ok" : "error");
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function payPayout(payoutId) {
    if (!payoutId) return;
    const out = await postJson("/weekly-payout", { payout_id: payoutId });
    toast(out.success ? "Payout marked as paid" : out.error || "Failed to mark paid", out.success ? "ok" : "error");
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  async function confirmCashReceived(orderId) {
    if (!orderId) return;
    const out = await postJson("/admin/confirm-cash-received", { order_id: orderId });
    toast(out.success ? "Cash confirmed" : out.error || "Failed to confirm cash", out.success ? "ok" : "error");
    if (out.success) setTimeout(() => location.reload(), 500);
  }

  function bindForms() {
    const formMap = {
      "store-add-form": addStore,
      "owner-add-form": addShopOwner,
      "delivery-add-form": addDeliveryAgent,
      "assign-delivery-form": assignDelivery,
    };
    Object.entries(formMap).forEach(([id, handler]) => {
      const form = document.getElementById(id);
      if (form) {
        form.addEventListener("submit", (e) => {
          e.preventDefault();
          handler(form);
        });
      }
    });
  }

  function bindActions() {
    document.addEventListener("click", (event) => {
      const btn = event.target.closest("[data-action]");
      if (!btn) return;
      const { action } = btn.dataset;
      if (action === "set-status") {
        setUserStatus(btn.dataset.id, btn.dataset.status);
      } else if (action === "approve-store") {
        approveStore(btn.dataset.id, btn.dataset.status);
      } else if (action === "remove-store") {
        removeStore(btn.dataset.id);
      } else if (action === "remove-owner") {
        removeShopOwner(btn.dataset.id);
      } else if (action === "generate-payout") {
        generatePayout(btn.dataset.ownerId);
      } else if (action === "pay-payout") {
        payPayout(btn.dataset.payoutId);
      } else if (action === "confirm-cash") {
        confirmCashReceived(btn.dataset.orderId);
      }
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    bindForms();
    bindActions();
  });

  window.AdminAPI = {
    toast,
    postJson,
    setUserStatus,
    approveStore,
    removeStore,
    addStore,
    addShopOwner,
    removeShopOwner,
    addDeliveryAgent,
    assignDelivery,
    generatePayout,
    payPayout,
    confirmCashReceived,
  };
})();
